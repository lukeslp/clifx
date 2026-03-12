#!/usr/bin/env python3
"""
gif2term — Convert GIF/video files to terminal frame animations.

Renders each frame as colored Unicode half-block characters (▀) with
true-color ANSI escapes. Each character cell = 2 vertical pixels using
foreground (top) and background (bottom) colors.

Output: clifx-compatible "--- Frame N ---" delimited text files with
embedded ANSI escape codes, playable via `./clifx play <name>`.

Usage:
    python3 tools/gif2term.py input.gif                    # auto-size to 60x30 chars
    python3 tools/gif2term.py input.gif -w 40 -h 20        # explicit size
    python3 tools/gif2term.py input.gif -o myanim           # custom output name
    python3 tools/gif2term.py input.gif --max-frames 30     # limit frame count
    python3 tools/gif2term.py input.gif --preview           # print frame 1 to terminal
    python3 tools/gif2term.py input.gif --dither            # enable dithering
    python3 tools/gif2term.py video.mp4 -w 50 -h 25        # works with video too

Output lands in ascii-animations/ as a .txt file.
"""

import argparse
import math
import os
import subprocess
import sys
import tempfile

try:
    from PIL import Image
except ImportError:
    print("Error: Pillow required. Install with: pip install Pillow", file=sys.stderr)
    sys.exit(1)

ANIM_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'ascii-animations')

# ANSI escape helpers
def fg_rgb(r, g, b):
    return f"\033[38;2;{r};{g};{b}m"

def bg_rgb(r, g, b):
    return f"\033[48;2;{r};{g};{b}m"

RESET = "\033[0m"

# Unicode half-block: top half is foreground color, bottom half is background color
HALF_BLOCK = "▀"


def extract_frames_gif(path, max_frames=None):
    """Extract frames from a GIF using Pillow."""
    img = Image.open(path)
    frames = []
    durations = []

    try:
        while True:
            # Convert to RGBA to handle transparency
            frame = img.convert("RGBA")

            # Composite onto black background
            bg = Image.new("RGBA", frame.size, (0, 0, 0, 255))
            composited = Image.alpha_composite(bg, frame)
            frames.append(composited.convert("RGB"))

            duration = img.info.get('duration', 100)  # ms per frame
            durations.append(duration)

            if max_frames and len(frames) >= max_frames:
                break

            img.seek(img.tell() + 1)
    except EOFError:
        pass

    avg_duration = sum(durations) / len(durations) if durations else 100
    fps = max(1, min(60, round(1000 / avg_duration)))

    return frames, fps


def extract_frames_video(path, max_frames=None):
    """Extract frames from a video file using ffmpeg."""
    with tempfile.TemporaryDirectory() as tmpdir:
        # Get video info
        probe = subprocess.run(
            ['ffprobe', '-v', 'quiet', '-print_format', 'flat',
             '-select_streams', 'v:0', '-show_entries',
             'stream=r_frame_rate,nb_frames,duration',
             path],
            capture_output=True, text=True
        )

        # Extract frames as PNG
        cmd = ['ffmpeg', '-i', path, '-vf', 'fps=12', '-y']
        if max_frames:
            cmd += ['-vframes', str(max_frames)]
        cmd += [os.path.join(tmpdir, 'frame_%04d.png')]

        subprocess.run(cmd, capture_output=True, check=True)

        # Load frames
        frames = []
        frame_files = sorted(
            f for f in os.listdir(tmpdir) if f.startswith('frame_')
        )
        for fname in frame_files:
            img = Image.open(os.path.join(tmpdir, fname)).convert("RGB")
            frames.append(img)

    return frames, 12


def frame_to_halfblock(img, width, height, dither=False):
    """
    Convert an image to colored half-block text.

    Each character cell represents 2 vertical pixels:
    - Foreground color = top pixel
    - Background color = bottom pixel
    - Character = ▀ (upper half block)

    Args:
        img: PIL Image (RGB)
        width: output width in characters
        height: output height in characters (each char = 2 pixel rows)
        dither: apply Floyd-Steinberg dithering to reduce banding
    """
    # Resize: width chars, height*2 pixel rows
    pixel_h = height * 2
    resized = img.resize((width, pixel_h), Image.LANCZOS)

    if dither:
        # Quantize to reduce color count, then convert back
        resized = resized.quantize(colors=64, dither=Image.Dither.FLOYDSTEINBERG)
        resized = resized.convert("RGB")

    pixels = resized.load()
    lines = []

    for row in range(height):
        line = ""
        py_top = row * 2
        py_bot = row * 2 + 1

        prev_fg = None
        prev_bg = None

        for col in range(width):
            r_top, g_top, b_top = pixels[col, py_top]
            if py_bot < pixel_h:
                r_bot, g_bot, b_bot = pixels[col, py_bot]
            else:
                r_bot, g_bot, b_bot = 0, 0, 0

            # Optimization: skip color codes if same as previous
            fg = (r_top, g_top, b_top)
            bg = (r_bot, g_bot, b_bot)

            codes = ""
            if fg != prev_fg:
                codes += fg_rgb(*fg)
                prev_fg = fg
            if bg != prev_bg:
                codes += bg_rgb(*bg)
                prev_bg = bg

            line += codes + HALF_BLOCK

        line += RESET
        lines.append(line)

    return "\n".join(lines)


def convert(input_path, width=60, height=30, output_name=None,
            max_frames=None, dither=False, preview=False):
    """Convert a GIF/video to a clifx animation file."""

    if not os.path.isfile(input_path):
        print(f"Error: File not found: {input_path}", file=sys.stderr)
        return 1

    ext = os.path.splitext(input_path)[1].lower()
    basename = os.path.splitext(os.path.basename(input_path))[0]

    print(f"Loading {input_path}...")

    if ext == '.gif':
        frames, fps = extract_frames_gif(input_path, max_frames)
    elif ext in ('.mp4', '.webm', '.avi', '.mov', '.mkv'):
        frames, fps = extract_frames_video(input_path, max_frames)
    else:
        # Try as image sequence or let Pillow figure it out
        try:
            frames, fps = extract_frames_gif(input_path, max_frames)
        except Exception:
            print(f"Error: Unsupported format: {ext}", file=sys.stderr)
            return 1

    print(f"  {len(frames)} frames at ~{fps} fps")
    print(f"  Source size: {frames[0].size[0]}x{frames[0].size[1]}")
    print(f"  Output size: {width}x{height} chars ({width}x{height*2} pixels)")

    # Convert frames
    print("Converting frames...")
    converted = []
    for i, frame in enumerate(frames):
        text = frame_to_halfblock(frame, width, height, dither=dither)
        converted.append(text)
        # Progress
        if (i + 1) % 10 == 0 or i == len(frames) - 1:
            pct = (i + 1) / len(frames) * 100
            print(f"  [{i+1}/{len(frames)}] {pct:.0f}%", end='\r')
    print()

    if preview:
        print("\n--- Preview (Frame 1) ---")
        print(converted[0])
        print("--- End Preview ---\n")

    # Write output
    if output_name is None:
        output_name = f"term-{basename}"

    os.makedirs(ANIM_DIR, exist_ok=True)
    output_path = os.path.join(ANIM_DIR, f"{output_name}.txt")

    with open(output_path, 'w') as f:
        for i, frame_text in enumerate(converted, 1):
            f.write(f"--- Frame {i} ---\n")
            f.write(frame_text)
            f.write("\n")

    file_size = os.path.getsize(output_path)
    size_str = f"{file_size / 1024:.1f}K" if file_size < 1024 * 1024 else f"{file_size / 1024 / 1024:.1f}M"

    print(f"Wrote: {output_path}")
    print(f"  {len(converted)} frames, {size_str}")
    print(f"  Play: ./clifx play {output_name} {fps}")

    return 0


def main():
    parser = argparse.ArgumentParser(
        description="Convert GIF/video to terminal frame animation",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""\
Examples:
  %(prog)s explosion.gif                     # 60x30 chars, auto fps
  %(prog)s explosion.gif -w 40 -h 20         # smaller for 80x24 terminals
  %(prog)s cutscene.gif -o intro --preview    # name it "intro", preview frame 1
  %(prog)s clip.mp4 --max-frames 60           # cap at 60 frames
  %(prog)s sprite.gif -w 20 -h 10 --dither    # tiny sprite with dithering
"""
    )
    parser.add_argument('input', help='GIF or video file to convert')
    parser.add_argument('-w', '--width', type=int, default=60,
                        help='Output width in characters (default: 60)')
    parser.add_argument('-ht', '--height', type=int, default=30,
                        help='Output height in characters, each = 2px rows (default: 30)')
    parser.add_argument('-o', '--output', type=str, default=None,
                        help='Output name (without .txt extension)')
    parser.add_argument('--max-frames', type=int, default=None,
                        help='Maximum number of frames to extract')
    parser.add_argument('--dither', action='store_true',
                        help='Apply dithering to reduce color banding')
    parser.add_argument('--preview', action='store_true',
                        help='Print first frame to terminal after conversion')
    parser.add_argument('--fps', type=int, default=None,
                        help='Override detected FPS for playback suggestion')

    args = parser.parse_args()

    sys.exit(convert(
        input_path=args.input,
        width=args.width,
        height=args.height,
        output_name=args.output,
        max_frames=args.max_frames,
        dither=args.dither,
        preview=args.preview,
    ))


if __name__ == '__main__':
    main()
