#!/usr/bin/env python3
"""
tools/effects/plasma.py — High-performance plasma field effect.

Renders a smooth, animated plasma field using true-color ANSI escape codes.
Each cell is computed from overlapping sine waves, producing organic color
cycling that is far smoother than the Bash fallback.

Usage (called by manifest_atmosphere.sh):
    python3 tools/effects/plasma.py [--duration 4] [--speed 30] [--cols 80] [--rows 24]

Outputs ANSI-escaped frames to stdout. The Bash wrapper reads these and
forwards them to the terminal, then restores the cursor on exit.
"""

import argparse
import math
import os
import sys
import time
import signal

# ANSI helpers
def fg_rgb(r, g, b):
    return f"\033[38;2;{r};{g};{b}m"

def bg_rgb(r, g, b):
    return f"\033[48;2;{r};{g};{b}m"

RESET = "\033[0m"
HIDE_CURSOR = "\033[?25l"
SHOW_CURSOR = "\033[?25h"
CLEAR_SCREEN = "\033[2J\033[H"
MOVE_HOME = "\033[H"

# Block characters for density variation
BLOCKS = [" ", "░", "▒", "▓", "█"]


def hsv_to_rgb(h, s, v):
    """Convert HSV (0-1 each) to RGB (0-255 each)."""
    if s == 0:
        c = int(v * 255)
        return c, c, c
    h6 = h * 6.0
    i = int(h6)
    f = h6 - i
    p = v * (1 - s)
    q = v * (1 - s * f)
    t = v * (1 - s * (1 - f))
    i %= 6
    if i == 0:   r, g, b = v, t, p
    elif i == 1: r, g, b = q, v, p
    elif i == 2: r, g, b = p, v, t
    elif i == 3: r, g, b = p, q, v
    elif i == 4: r, g, b = t, p, v
    else:        r, g, b = v, p, q
    return int(r * 255), int(g * 255), int(b * 255)


def render_frame(cols, rows, t, base_hue=0.33):
    """
    Render one plasma frame.

    Uses three overlapping sine waves with different frequencies and phases
    to produce a smooth, organic color field. Each cell gets a hue derived
    from the wave sum, with saturation and value varied by position.
    """
    lines = []
    for row in range(rows):
        line_parts = []
        prev_fg = None
        prev_bg = None

        for col in range(cols):
            # Normalized coordinates
            nx = col / cols
            ny = row / rows

            # Three overlapping waves
            v1 = math.sin(nx * 6 + t)
            v2 = math.sin(ny * 5 - t * 0.7)
            v3 = math.sin((nx + ny) * 4 + t * 1.3)
            v4 = math.sin(math.sqrt((nx - 0.5) ** 2 + (ny - 0.5) ** 2) * 8 - t)

            val = (v1 + v2 + v3 + v4) / 4.0  # range [-1, 1]
            norm = (val + 1) / 2.0             # range [0, 1]

            # Map to hue, cycling around the base hue
            hue = (base_hue + norm * 0.6) % 1.0
            sat = 0.7 + 0.3 * abs(math.sin(val * math.pi))
            bri = 0.4 + 0.4 * norm

            r, g, b = hsv_to_rgb(hue, sat, bri)

            # Background slightly darker
            rb, gb, bb = hsv_to_rgb(hue, sat, bri * 0.5)

            # Choose block character by brightness
            block_idx = int(norm * (len(BLOCKS) - 1))
            char = BLOCKS[block_idx]

            # Emit color codes only when they change (optimization)
            fg_code = fg_rgb(r, g, b)
            bg_code = bg_rgb(rb, gb, bb)

            codes = ""
            if fg_code != prev_fg:
                codes += fg_code
                prev_fg = fg_code
            if bg_code != prev_bg:
                codes += bg_code
                prev_bg = bg_code

            line_parts.append(codes + char)

        lines.append("".join(line_parts) + RESET)

    return "\n".join(lines)


def run(duration, speed_ms, cols, rows, base_hue):
    """Main render loop."""
    sys.stdout.write(HIDE_CURSOR + CLEAR_SCREEN)
    sys.stdout.flush()

    def cleanup(sig=None, frame=None):
        sys.stdout.write(SHOW_CURSOR + RESET + "\n")
        sys.stdout.flush()
        sys.exit(0)

    signal.signal(signal.SIGINT, cleanup)
    signal.signal(signal.SIGTERM, cleanup)

    start = time.time()
    t = 0.0
    step = speed_ms / 1000.0 * 2.0  # time increment per frame

    while time.time() - start < duration:
        frame = render_frame(cols, rows, t, base_hue)
        sys.stdout.write(MOVE_HOME + frame)
        sys.stdout.flush()
        time.sleep(speed_ms / 1000.0)
        t += step

    cleanup()


def main():
    parser = argparse.ArgumentParser(description="High-performance plasma effect")
    parser.add_argument("--duration", type=float, default=4.0,
                        help="Duration in seconds (default: 4)")
    parser.add_argument("--speed", type=int, default=30,
                        help="Frame delay in milliseconds (default: 30)")
    parser.add_argument("--cols", type=int, default=80,
                        help="Terminal columns (default: 80)")
    parser.add_argument("--rows", type=int, default=24,
                        help="Terminal rows (default: 24)")
    parser.add_argument("--hue", type=float, default=0.33,
                        help="Base hue 0.0-1.0 (default: 0.33 = green)")
    args = parser.parse_args()

    run(args.duration, args.speed, args.cols, args.rows, args.hue)


if __name__ == "__main__":
    main()
