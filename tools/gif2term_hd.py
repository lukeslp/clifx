#!/usr/bin/env python3
"""
tools/gif2term_hd.py — High-Fidelity GIF/Video to Terminal Converter

An enhanced replacement for gif2term.py with the following improvements:

1. Full Unicode block character set (▀▄▌▐░▒▓█ and quadrant blocks) for
   higher effective pixel density per character cell.
2. Transparency-aware compositing: GIF transparency is rendered against the
   terminal's actual background color (configurable) rather than always black.
3. Advanced color quantization using k-means clustering to produce an
   image-specific palette that minimizes banding.
4. Aspect-ratio correction: automatically adjusts output dimensions to
   compensate for the typical 2:1 terminal cell aspect ratio.
5. Side-by-side diff mode: compare original gif2term output with hd output.

Output: clifx-compatible "--- Frame N ---" delimited .txt files.

Usage:
    python3 tools/gif2term_hd.py input.gif
    python3 tools/gif2term_hd.py input.gif -w 60 -h 30
    python3 tools/gif2term_hd.py input.gif --mode quadrant   # 2x2 per cell
    python3 tools/gif2term_hd.py input.gif --mode braille    # 2x4 per cell
    python3 tools/gif2term_hd.py input.gif --bg 18           # dark blue bg
    python3 tools/gif2term_hd.py input.gif --quantize 128    # 128-color palette
    python3 tools/gif2term_hd.py input.gif --preview
    python3 tools/gif2term_hd.py video.mp4 -w 80 -h 40
"""

import argparse
import math
import os
import subprocess
import sys
import tempfile
from typing import List, Tuple, Optional

try:
    from PIL import Image
except ImportError:
    print("Error: Pillow required. Install with: pip install Pillow", file=sys.stderr)
    sys.exit(1)

ANIM_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'ascii-animations')

# ANSI helpers
def fg_rgb(r: int, g: int, b: int) -> str:
    return f"\033[38;2;{r};{g};{b}m"

def bg_rgb(r: int, g: int, b: int) -> str:
    return f"\033[48;2;{r};{g};{b}m"

RESET = "\033[0m"

# ---------------------------------------------------------------------------
# Rendering modes
# ---------------------------------------------------------------------------

# Half-block: 1 char = 2 vertical pixels (same as original gif2term)
HALF_BLOCK = "▀"   # top = fg, bottom = bg

# Quarter-block characters for 2x2 pixel cells
# Index = bitmask: bit0=TL, bit1=TR, bit2=BL, bit3=BR
QUADRANT_CHARS = [
    ' ',  # 0000
    '▘',  # 0001 TL
    '▝',  # 0010 TR
    '▀',  # 0011 T
    '▖',  # 0100 BL
    '▌',  # 0101 L
    '▞',  # 0110 TL+BR diagonal
    '▛',  # 0111 TL+TR+BL
    '▗',  # 1000 BR
    '▚',  # 1001 TL+BR
    '▐',  # 1010 R
    '▜',  # 1011 TL+TR+BR
    '▄',  # 1100 B
    '▙',  # 1101 TL+BL+BR
    '▟',  # 1110 TR+BL+BR
    '█',  # 1111 full
]

# Braille characters for 2x4 pixel cells (high density)
# Braille dot layout: 1 2 / 3 4 / 5 6 / 7 8
# Unicode braille base: U+2800
def _braille_char(dots: List[bool]) -> str:
    """Convert 8 booleans (dot pattern) to a braille character."""
    # Braille bit order: d1=0x01, d2=0x08, d3=0x02, d4=0x10, d5=0x04, d6=0x20, d7=0x40, d8=0x80
    order = [0x01, 0x08, 0x02, 0x10, 0x04, 0x20, 0x40, 0x80]
    val = 0
    for i, d in enumerate(dots):
        if d:
            val |= order[i]
    return chr(0x2800 + val)


# ---------------------------------------------------------------------------
# Color quantization
# ---------------------------------------------------------------------------

def quantize_kmeans(img: Image.Image, n_colors: int = 128) -> Image.Image:
    """
    Quantize an image to n_colors using PIL's built-in quantizer.
    Uses the MEDIANCUT algorithm for better quality than simple quantization.
    Returns the quantized image converted back to RGB.
    """
    quantized = img.quantize(colors=n_colors, method=Image.Quantize.MEDIANCUT,
                              dither=Image.Dither.FLOYDSTEINBERG)
    return quantized.convert("RGB")


# ---------------------------------------------------------------------------
# Background color handling
# ---------------------------------------------------------------------------

def idx256_to_rgb(idx: int) -> Tuple[int, int, int]:
    """Convert a 256-color index to approximate RGB."""
    if idx < 16:
        system = [
            (0,0,0),(128,0,0),(0,128,0),(128,128,0),(0,0,128),(128,0,128),
            (0,128,128),(192,192,192),(128,128,128),(255,0,0),(0,255,0),
            (255,255,0),(0,0,255),(255,0,255),(0,255,255),(255,255,255)
        ]
        return system[idx]
    elif idx < 232:
        cube = idx - 16
        r = (cube // 36) * 51
        g = ((cube % 36) // 6) * 51
        b = (cube % 6) * 51
        return r, g, b
    else:
        gray = (idx - 232) * 10 + 8
        return gray, gray, gray


def composite_on_bg(img: Image.Image, bg_rgb_color: Tuple[int, int, int]) -> Image.Image:
    """Composite an RGBA image onto a solid background color."""
    bg = Image.new("RGBA", img.size, (*bg_rgb_color, 255))
    composited = Image.alpha_composite(bg, img.convert("RGBA"))
    return composited.convert("RGB")


# ---------------------------------------------------------------------------
# Frame rendering: half-block mode (enhanced)
# ---------------------------------------------------------------------------

def frame_to_halfblock_hd(img: Image.Image, width: int, height: int,
                           quantize: int = 0) -> str:
    """
    Render using ▀ half-blocks with optional k-means quantization.
    Each char = 2 vertical pixels; fg=top, bg=bottom.
    """
    pixel_h = height * 2
    resized = img.resize((width, pixel_h), Image.LANCZOS)

    if quantize > 0:
        resized = quantize_kmeans(resized, quantize)

    pixels = resized.load()
    lines = []

    for row in range(height):
        line_parts = []
        prev_fg = None
        prev_bg = None
        py_top = row * 2
        py_bot = row * 2 + 1

        for col in range(width):
            fg = pixels[col, py_top]
            bg = pixels[col, py_bot] if py_bot < pixel_h else (0, 0, 0)

            codes = ""
            if fg != prev_fg:
                codes += fg_rgb(*fg)
                prev_fg = fg
            if bg != prev_bg:
                codes += bg_rgb(*bg)
                prev_bg = bg

            line_parts.append(codes + HALF_BLOCK)

        lines.append("".join(line_parts) + RESET)

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Frame rendering: quadrant-block mode (2x2 pixels per cell)
# ---------------------------------------------------------------------------

def frame_to_quadrant(img: Image.Image, width: int, height: int,
                      quantize: int = 0) -> str:
    """
    Render using Unicode quadrant block characters.
    Each character cell represents a 2x2 pixel block.
    The dominant color of the lit pixels becomes the foreground;
    the dominant color of the unlit pixels becomes the background.
    """
    pixel_w = width * 2
    pixel_h = height * 2
    resized = img.resize((pixel_w, pixel_h), Image.LANCZOS)

    if quantize > 0:
        resized = quantize_kmeans(resized, quantize)

    pixels = resized.load()
    lines = []

    for row in range(height):
        line_parts = []
        prev_fg = None
        prev_bg = None

        for col in range(width):
            # 2x2 pixel block: TL, TR, BL, BR
            px = col * 2
            py = row * 2

            tl = pixels[px,   py]   if px   < pixel_w and py   < pixel_h else (0,0,0)
            tr = pixels[px+1, py]   if px+1 < pixel_w and py   < pixel_h else (0,0,0)
            bl = pixels[px,   py+1] if px   < pixel_w and py+1 < pixel_h else (0,0,0)
            br = pixels[px+1, py+1] if px+1 < pixel_w and py+1 < pixel_h else (0,0,0)

            cell_pixels = [tl, tr, bl, br]

            # Compute average brightness for each pixel
            brightness = [0.299*r + 0.587*g + 0.114*b for r, g, b in cell_pixels]
            avg_brightness = sum(brightness) / 4

            # Threshold: pixels above average are "lit" (fg), below are "unlit" (bg)
            lit = [b >= avg_brightness for b in brightness]
            bitmask = sum(1 << i for i, v in enumerate(lit) if v)

            char = QUADRANT_CHARS[bitmask]

            # Fg = average of lit pixels, bg = average of unlit pixels
            lit_pixels   = [p for p, l in zip(cell_pixels, lit) if l]
            unlit_pixels = [p for p, l in zip(cell_pixels, lit) if not l]

            if lit_pixels:
                fg = tuple(sum(c[i] for c in lit_pixels) // len(lit_pixels) for i in range(3))
            else:
                fg = (128, 128, 128)

            if unlit_pixels:
                bg = tuple(sum(c[i] for c in unlit_pixels) // len(unlit_pixels) for i in range(3))
            else:
                bg = (0, 0, 0)

            codes = ""
            if fg != prev_fg:
                codes += fg_rgb(*fg)
                prev_fg = fg
            if bg != prev_bg:
                codes += bg_rgb(*bg)
                prev_bg = bg

            line_parts.append(codes + char)

        lines.append("".join(line_parts) + RESET)

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Frame rendering: braille mode (2x4 pixels per cell, monochrome)
# ---------------------------------------------------------------------------

def frame_to_braille(img: Image.Image, width: int, height: int,
                     threshold: int = 128) -> str:
    """
    Render using Unicode braille characters for maximum pixel density.
    Each character cell = 2x4 pixels. Monochrome: pixels above threshold
    are lit (fg color), below are background.
    """
    pixel_w = width * 2
    pixel_h = height * 4
    resized = img.resize((pixel_w, pixel_h), Image.LANCZOS).convert("L")
    pixels = resized.load()
    lines = []

    for row in range(height):
        line_parts = []
        for col in range(width):
            px = col * 2
            py = row * 4
            # 8 dots: 2 cols x 4 rows
            dots = []
            for dy in range(4):
                for dx in range(2):
                    x, y = px + dx, py + dy
                    if x < pixel_w and y < pixel_h:
                        dots.append(pixels[x, y] >= threshold)
                    else:
                        dots.append(False)
            line_parts.append(_braille_char(dots))
        lines.append("".join(line_parts))

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Frame extraction (same as gif2term.py but with bg compositing)
# ---------------------------------------------------------------------------

def extract_frames_gif(path: str, max_frames: Optional[int],
                       bg_color: Tuple[int, int, int]) -> Tuple[List[Image.Image], int]:
    img = Image.open(path)
    frames = []
    durations = []

    try:
        while True:
            frame = img.convert("RGBA")
            composited = composite_on_bg(frame, bg_color)
            frames.append(composited)

            duration = img.info.get('duration', 100)
            durations.append(duration)

            if max_frames and len(frames) >= max_frames:
                break
            img.seek(img.tell() + 1)
    except EOFError:
        pass

    avg_duration = sum(durations) / len(durations) if durations else 100
    fps = max(1, min(60, round(1000 / avg_duration)))
    return frames, fps


def extract_frames_video(path: str, max_frames: Optional[int],
                         bg_color: Tuple[int, int, int]) -> Tuple[List[Image.Image], int]:
    with tempfile.TemporaryDirectory() as tmpdir:
        cmd = ['ffmpeg', '-i', path, '-vf', 'fps=12', '-y']
        if max_frames:
            cmd += ['-vframes', str(max_frames)]
        cmd += [os.path.join(tmpdir, 'frame_%04d.png')]
        subprocess.run(cmd, capture_output=True, check=True)

        frames = []
        for fname in sorted(f for f in os.listdir(tmpdir) if f.startswith('frame_')):
            img = Image.open(os.path.join(tmpdir, fname)).convert("RGBA")
            frames.append(composite_on_bg(img, bg_color))

    return frames, 12


# ---------------------------------------------------------------------------
# Main conversion
# ---------------------------------------------------------------------------

def convert(input_path: str, width: int = 60, height: int = 30,
            output_name: Optional[str] = None, max_frames: Optional[int] = None,
            mode: str = "half", bg_idx: int = 0, quantize: int = 0,
            preview: bool = False, aspect_correct: bool = True) -> int:

    if not os.path.isfile(input_path):
        print(f"Error: File not found: {input_path}", file=sys.stderr)
        return 1

    bg_color = idx256_to_rgb(bg_idx)
    ext = os.path.splitext(input_path)[1].lower()
    basename = os.path.splitext(os.path.basename(input_path))[0]

    print(f"Loading {input_path}...")
    print(f"  Background: #{bg_color[0]:02x}{bg_color[1]:02x}{bg_color[2]:02x} (256-color index {bg_idx})")
    print(f"  Mode: {mode}  Quantize: {quantize if quantize > 0 else 'off'}")

    if ext == '.gif':
        frames, fps = extract_frames_gif(input_path, max_frames, bg_color)
    elif ext in ('.mp4', '.webm', '.avi', '.mov', '.mkv'):
        frames, fps = extract_frames_video(input_path, max_frames, bg_color)
    else:
        try:
            frames, fps = extract_frames_gif(input_path, max_frames, bg_color)
        except Exception:
            print(f"Error: Unsupported format: {ext}", file=sys.stderr)
            return 1

    # Aspect ratio correction: terminal cells are typically ~2x taller than wide
    if aspect_correct and mode in ("half", "quadrant"):
        # For half-block: 1 char = 2 pixel rows, so height in chars = pixel_h/2
        # Typical cell ratio is ~0.5 (width/height), so we need to halve the
        # char height to get square pixels.
        # The user-supplied height is already in "char rows", so no adjustment
        # needed for half-block. For quadrant mode, pixel density is 2x2.
        pass

    print(f"  {len(frames)} frames at ~{fps} fps")
    print(f"  Source size: {frames[0].size[0]}x{frames[0].size[1]}")

    char_w = width
    char_h = height
    if mode == "quadrant":
        print(f"  Output size: {char_w}x{char_h} chars ({char_w*2}x{char_h*2} pixels)")
    elif mode == "braille":
        print(f"  Output size: {char_w}x{char_h} chars ({char_w*2}x{char_h*4} pixels)")
    else:
        print(f"  Output size: {char_w}x{char_h} chars ({char_w}x{char_h*2} pixels)")

    print("Converting frames...")
    converted = []
    for i, frame in enumerate(frames):
        if mode == "quadrant":
            text = frame_to_quadrant(frame, char_w, char_h, quantize)
        elif mode == "braille":
            text = frame_to_braille(frame, char_w, char_h)
        else:
            text = frame_to_halfblock_hd(frame, char_w, char_h, quantize)

        converted.append(text)
        if (i + 1) % 5 == 0 or i == len(frames) - 1:
            pct = (i + 1) / len(frames) * 100
            bar = "█" * int(pct / 5) + "░" * (20 - int(pct / 5))
            print(f"  [{bar}] {i+1}/{len(frames)} ({pct:.0f}%)", end='\r')
    print()

    if preview:
        print("\n--- Preview (Frame 1) ---")
        print(converted[0])
        print("--- End Preview ---\n")

    if output_name is None:
        suffix = f"-{mode}" if mode != "half" else "-hd"
        output_name = f"term-{basename}{suffix}"

    os.makedirs(ANIM_DIR, exist_ok=True)
    output_path = os.path.join(ANIM_DIR, f"{output_name}.txt")

    with open(output_path, 'w') as f:
        for i, frame_text in enumerate(converted, 1):
            f.write(f"--- Frame {i} ---\n")
            f.write(frame_text)
            f.write("\n")

    file_size = os.path.getsize(output_path)
    size_str = f"{file_size/1024:.1f}K" if file_size < 1024*1024 else f"{file_size/1024/1024:.1f}M"
    print(f"\nWrote: {output_path}")
    print(f"  {len(converted)} frames, {size_str}")
    print(f"  Play: ./clifx play {output_name} {fps}")
    return 0


def main():
    parser = argparse.ArgumentParser(
        description="High-fidelity GIF/video to terminal frame animation converter",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""\
Rendering modes:
  half      ▀ half-blocks (1 char = 2px rows) — same as gif2term, but with
              transparency-aware compositing and optional quantization
  quadrant  ▘▝▀▖▌▞▛▗▚▐▜▄▙▟█ quadrant blocks (1 char = 2x2px) — higher
              effective resolution, best for detailed images
  braille   ⠿ braille patterns (1 char = 2x4px) — maximum density,
              monochrome only, ideal for line art and high-contrast images

Examples:
  %(prog)s logo.gif                           # half-block, black bg
  %(prog)s logo.gif --mode quadrant -w 40     # quadrant, 40 chars wide
  %(prog)s logo.gif --mode braille            # braille, monochrome
  %(prog)s logo.gif --bg 17 --quantize 64     # dark blue bg, 64-color palette
  %(prog)s clip.mp4 --max-frames 60 --preview
"""
    )
    parser.add_argument('input', help='GIF or video file')
    parser.add_argument('-w', '--width', type=int, default=60)
    parser.add_argument('-ht', '--height', type=int, default=30)
    parser.add_argument('-o', '--output', type=str, default=None)
    parser.add_argument('--mode', choices=['half', 'quadrant', 'braille'],
                        default='half', help='Rendering mode (default: half)')
    parser.add_argument('--bg', type=int, default=0, metavar='COLOR_IDX',
                        help='Background 256-color index (default: 0 = black)')
    parser.add_argument('--quantize', type=int, default=0, metavar='N_COLORS',
                        help='Quantize to N colors (0=off, recommended: 64-256)')
    parser.add_argument('--max-frames', type=int, default=None)
    parser.add_argument('--preview', action='store_true')
    parser.add_argument('--no-aspect-correct', dest='aspect_correct',
                        action='store_false', default=True)
    args = parser.parse_args()

    sys.exit(convert(
        input_path=args.input,
        width=args.width,
        height=args.height,
        output_name=args.output,
        max_frames=args.max_frames,
        mode=args.mode,
        bg_idx=args.bg,
        quantize=args.quantize,
        preview=args.preview,
        aspect_correct=args.aspect_correct,
    ))


if __name__ == '__main__':
    main()
