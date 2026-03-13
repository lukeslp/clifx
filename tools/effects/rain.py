#!/usr/bin/env python3
"""
tools/effects/rain.py — High-performance matrix rain effect.

Renders falling character columns with bright heads, dimming trails,
and true-color ANSI output. Supports far more simultaneous drops and
smoother animation than the Bash implementation.

Usage (called by manifest_spatial.sh):
    python3 tools/effects/rain.py [--duration 5] [--density 20] [--cols 80] [--rows 24]
    python3 tools/effects/rain.py --hue 0.33   # green (default)
    python3 tools/effects/rain.py --hue 0.5    # cyan
    python3 tools/effects/rain.py --hue 0.0    # red
"""

import argparse
import math
import random
import signal
import sys
import time

# ANSI helpers
RESET = "\033[0m"
HIDE_CURSOR = "\033[?25l"
SHOW_CURSOR = "\033[?25h"
CLEAR_SCREEN = "\033[2J\033[H"

def move(row, col):
    return f"\033[{row};{col}H"

def fg_rgb(r, g, b):
    return f"\033[38;2;{r};{g};{b}m"

def hsv_to_rgb(h, s, v):
    """Convert HSV (0-1) to RGB (0-255)."""
    if s == 0:
        c = int(v * 255)
        return c, c, c
    h6 = h * 6.0
    i = int(h6) % 6
    f = h6 - int(h6)
    p, q, t_ = v*(1-s), v*(1-s*f), v*(1-s*(1-f))
    pairs = [(v,t_,p),(q,v,p),(p,v,t_),(p,q,v),(t_,p,v),(v,p,q)]
    r, g, b = pairs[i]
    return int(r*255), int(g*255), int(b*255)

# Character pools
KATAKANA = "アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン"
LATIN    = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
BLOCKS   = "░▒▓█◈◆▲∷∴⊹⊛⌇"
ALL_CHARS = KATAKANA + LATIN + BLOCKS


class Drop:
    """A single falling character column."""

    def __init__(self, col, rows):
        self.col = col
        self.rows = rows
        self.reset()

    def reset(self):
        self.row = random.randint(-self.rows, 0)
        self.speed = random.uniform(0.5, 2.0)
        self.trail_len = random.randint(4, 14)
        self.chars = [random.choice(ALL_CHARS) for _ in range(self.trail_len + 2)]
        self.frac = 0.0  # sub-row accumulator

    def advance(self, dt):
        self.frac += self.speed * dt * 15  # ~15 rows/sec at speed=1
        steps = int(self.frac)
        self.frac -= steps
        self.row += steps
        # Randomly mutate a character in the trail
        if random.random() < 0.15:
            idx = random.randint(0, len(self.chars) - 1)
            self.chars[idx] = random.choice(ALL_CHARS)
        if self.row - self.trail_len > self.rows:
            self.reset()

    def render(self, hue):
        """Yield (row, col, ansi_string) tuples for each visible cell."""
        head_row = int(self.row)
        for i in range(self.trail_len + 1):
            r = head_row - i
            if r < 1 or r > self.rows:
                continue
            char = self.chars[i % len(self.chars)]
            if i == 0:
                # Bright white head
                yield r, self.col, f"\033[38;2;220;255;220m{char}{RESET}"
            elif i == 1:
                # Near-head: bright hue
                rr, gg, bb = hsv_to_rgb(hue, 0.3, 1.0)
                yield r, self.col, f"{fg_rgb(rr,gg,bb)}{char}{RESET}"
            else:
                # Trail: fade brightness with distance
                brightness = max(0.05, 1.0 - (i / self.trail_len) * 0.95)
                rr, gg, bb = hsv_to_rgb(hue, 0.9, brightness)
                yield r, self.col, f"{fg_rgb(rr,gg,bb)}{char}{RESET}"
            # Erase one cell below the tail
            tail_row = head_row - self.trail_len - 1
            if tail_row >= 1 and tail_row <= self.rows:
                yield tail_row, self.col, " "


def run(duration, density, cols, rows, hue, speed_mult):
    sys.stdout.write(HIDE_CURSOR + CLEAR_SCREEN)
    sys.stdout.flush()

    def cleanup(sig=None, frame=None):
        sys.stdout.write(SHOW_CURSOR + RESET + "\n")
        sys.stdout.flush()
        sys.exit(0)

    signal.signal(signal.SIGINT, cleanup)
    signal.signal(signal.SIGTERM, cleanup)

    # Spawn drops proportional to density and column count
    num_drops = max(1, cols * density // 100)
    drops = []
    for c in range(1, cols + 1, max(1, cols // num_drops)):
        drops.append(Drop(c, rows))

    start = time.time()
    last = start
    frame_delay = 0.04 * (speed_mult / 100.0)  # ~25fps base

    while time.time() - start < duration:
        now = time.time()
        dt = now - last
        last = now

        buf = []
        for drop in drops:
            drop.advance(dt)
            for row, col, s in drop.render(hue):
                buf.append(move(row, col) + s)

        sys.stdout.write("".join(buf))
        sys.stdout.flush()

        elapsed = time.time() - now
        sleep = max(0, frame_delay - elapsed)
        if sleep > 0:
            time.sleep(sleep)

    cleanup()


def main():
    parser = argparse.ArgumentParser(description="High-performance matrix rain effect")
    parser.add_argument("--duration", type=float, default=5.0)
    parser.add_argument("--density", type=int, default=20,
                        help="Drop density as %% of columns (default: 20)")
    parser.add_argument("--cols", type=int, default=80)
    parser.add_argument("--rows", type=int, default=24)
    parser.add_argument("--hue", type=float, default=0.33,
                        help="Base hue 0.0-1.0 (default: 0.33 = green)")
    parser.add_argument("--speed-mult", type=int, default=100,
                        help="Speed multiplier %% (default: 100)")
    args = parser.parse_args()

    run(args.duration, args.density, args.cols, args.rows, args.hue, args.speed_mult)


if __name__ == "__main__":
    main()
