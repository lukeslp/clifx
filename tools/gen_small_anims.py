#!/usr/bin/env python3
"""Generate compact ASCII animations sized for standard terminals (40w x 20h)."""

import math
import os

ANIM_DIR = os.path.join(os.path.dirname(__file__), '..', 'ascii-animations')


def write_anim(name, frames):
    path = os.path.join(ANIM_DIR, f'{name}.txt')
    with open(path, 'w') as f:
        for i, frame in enumerate(frames, 1):
            f.write(f'--- Frame {i} ---\n')
            f.write(frame)
            if not frame.endswith('\n'):
                f.write('\n')
    print(f'  {name}.txt: {len(frames)} frames')


def gen_mini_spinner():
    """Small rotating spinner/gear — 20w x 10h, 12 frames."""
    W, H = 20, 10
    frames = []
    chars = '|/-\\'
    dots = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'

    for t in range(12):
        lines = []
        cx, cy = W // 2, H // 2
        angle = t * (2 * math.pi / 12)

        grid = [[' '] * W for _ in range(H)]

        # Draw circle
        for a in range(60):
            aa = a * (2 * math.pi / 60)
            r = 3.5
            x = int(cx + r * math.cos(aa))
            y = int(cy + r * math.sin(aa) * 0.5)
            if 0 <= x < W and 0 <= y < H:
                grid[y][x] = '.'

        # Draw rotating spokes
        for spoke in range(3):
            sa = angle + spoke * (2 * math.pi / 3)
            for d in range(1, 4):
                x = int(cx + d * math.cos(sa))
                y = int(cy + d * math.sin(sa) * 0.5)
                if 0 <= x < W and 0 <= y < H:
                    grid[y][x] = '░' if d < 3 else '▒'

        # Center hub
        grid[cy][cx] = '◉'

        lines = [''.join(row).rstrip() for row in grid]
        frames.append('\n'.join(lines))

    write_anim('mini-spinner', frames)


def gen_mini_cube():
    """Rotating wireframe cube — 30w x 16h, 24 frames."""
    W, H = 30, 16
    frames = []

    # 3D cube vertices
    verts = [
        (-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1),
        (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1),
    ]
    edges = [
        (0,1),(1,2),(2,3),(3,0),  # back
        (4,5),(5,6),(6,7),(7,4),  # front
        (0,4),(1,5),(2,6),(3,7),  # connectors
    ]

    for t in range(24):
        angle_y = t * (2 * math.pi / 24)
        angle_x = t * (2 * math.pi / 48)

        # Rotate and project
        def project(v):
            x, y, z = v
            # Rotate Y
            x2 = x * math.cos(angle_y) - z * math.sin(angle_y)
            z2 = x * math.sin(angle_y) + z * math.cos(angle_y)
            # Rotate X
            y2 = y * math.cos(angle_x) - z2 * math.sin(angle_x)
            z3 = y * math.sin(angle_x) + z2 * math.cos(angle_x)
            # Perspective
            scale = 5.0 / (3.0 + z3)
            sx = int(W // 2 + x2 * scale * 6)
            sy = int(H // 2 + y2 * scale * 3)
            return sx, sy, z3

        grid = [[' '] * W for _ in range(H)]

        projected = [project(v) for v in verts]

        # Draw edges using Bresenham-lite
        for a, b in edges:
            x0, y0, z0 = projected[a]
            x1, y1, z1 = projected[b]
            steps = max(abs(x1 - x0), abs(y1 - y0), 1)
            avg_z = (z0 + z1) / 2
            ch = '█' if avg_z > 0 else '░'
            for s in range(steps + 1):
                frac = s / steps if steps > 0 else 0
                x = int(x0 + (x1 - x0) * frac)
                y = int(y0 + (y1 - y0) * frac)
                if 0 <= x < W and 0 <= y < H:
                    grid[y][x] = ch

        # Draw vertices
        for sx, sy, sz in projected:
            if 0 <= sx < W and 0 <= sy < H:
                grid[sy][sx] = '◆' if sz > 0 else '◇'

        lines = [''.join(row).rstrip() for row in grid]
        frames.append('\n'.join(lines))

    write_anim('mini-cube', frames)


def gen_mini_wave():
    """Sine wave animation — 36w x 14h, 16 frames."""
    W, H = 36, 14
    frames = []

    for t in range(16):
        grid = [[' '] * W for _ in range(H)]
        phase = t * (2 * math.pi / 16)

        for x in range(W):
            # Two overlapping waves
            y1 = int(H // 2 + 4 * math.sin(x * 0.3 + phase))
            y2 = int(H // 2 + 3 * math.sin(x * 0.2 - phase * 0.7))

            if 0 <= y1 < H:
                grid[y1][x] = '█'
            if 0 <= y2 < H:
                existing = grid[y2][x]
                grid[y2][x] = '▓' if existing == '█' else '░'

            # Fill below wave 1
            for y in range(y1 + 1, H):
                if 0 <= y < H and grid[y][x] == ' ':
                    grid[y][x] = '·'

        lines = [''.join(row).rstrip() for row in grid]
        frames.append('\n'.join(lines))

    write_anim('mini-wave', frames)


def gen_mini_spiral():
    """Spiral pattern — 30w x 16h, 20 frames."""
    W, H = 30, 16
    frames = []
    chars = ' ·░▒▓█'

    for t in range(20):
        grid = [[' '] * W for _ in range(H)]
        cx, cy = W / 2, H / 2
        phase = t * (2 * math.pi / 20)

        for y in range(H):
            for x in range(W):
                dx = (x - cx) / (W / 2)
                dy = (y - cy) / (H / 2) * 2  # aspect ratio correction
                dist = math.sqrt(dx * dx + dy * dy)
                angle = math.atan2(dy, dx)

                val = math.sin(dist * 6 - phase + angle * 2)
                idx = int((val + 1) / 2 * (len(chars) - 1))
                idx = max(0, min(len(chars) - 1, idx))

                if dist < 1.1:
                    grid[y][x] = chars[idx]

        lines = [''.join(row).rstrip() for row in grid]
        frames.append('\n'.join(lines))

    write_anim('mini-spiral', frames)


def gen_mini_pulse():
    """Expanding/contracting rings — 30w x 16h, 16 frames."""
    W, H = 30, 16
    frames = []

    for t in range(16):
        grid = [[' '] * W for _ in range(H)]
        cx, cy = W / 2, H / 2
        phase = t * (2 * math.pi / 16)

        for ring in range(4):
            r = 1.5 + ring * 1.8 + 0.8 * math.sin(phase + ring * 0.8)
            points = max(20, int(r * 12))
            for p in range(points):
                a = p * (2 * math.pi / points)
                x = int(cx + r * math.cos(a) * 2)  # wider for aspect ratio
                y = int(cy + r * math.sin(a))
                if 0 <= x < W and 0 <= y < H:
                    depth = (ring + 1) / 4
                    if depth > 0.75:
                        grid[y][x] = '█'
                    elif depth > 0.5:
                        grid[y][x] = '▓'
                    elif depth > 0.25:
                        grid[y][x] = '░'
                    else:
                        grid[y][x] = '·'

        # Center dot
        if 0 <= int(cy) < H and 0 <= int(cx) < W:
            grid[int(cy)][int(cx)] = '◉'

        lines = [''.join(row).rstrip() for row in grid]
        frames.append('\n'.join(lines))

    write_anim('mini-pulse', frames)


def gen_mini_matrix():
    """Falling characters — 36w x 18h, 20 frames."""
    import random
    random.seed(42)  # deterministic

    W, H = 36, 18
    num_drops = 8

    # Initialize drops
    drops = []
    for _ in range(num_drops):
        drops.append({
            'x': random.randint(0, W - 1),
            'y': random.randint(-H, 0),
            'speed': random.randint(1, 2),
            'length': random.randint(4, 8),
            'chars': [random.choice('01アイウエオカキクケコ░▒▓') for _ in range(10)]
        })

    frames = []
    for t in range(20):
        grid = [[' '] * W for _ in range(H)]

        for drop in drops:
            head_y = drop['y']
            for i in range(drop['length']):
                y = head_y - i
                if 0 <= y < H and 0 <= drop['x'] < W:
                    if i == 0:
                        grid[y][drop['x']] = '█'
                    elif i < 2:
                        grid[y][drop['x']] = '▓'
                    elif i < 4:
                        grid[y][drop['x']] = '░'
                    else:
                        grid[y][drop['x']] = '·'

            drop['y'] += drop['speed']
            if drop['y'] - drop['length'] > H:
                drop['y'] = random.randint(-6, -1)
                drop['x'] = random.randint(0, W - 1)
                drop['length'] = random.randint(4, 8)

        lines = [''.join(row).rstrip() for row in grid]
        frames.append('\n'.join(lines))

    write_anim('mini-rain', frames)


if __name__ == '__main__':
    print('Generating compact animations...')
    gen_mini_spinner()
    gen_mini_cube()
    gen_mini_wave()
    gen_mini_spiral()
    gen_mini_pulse()
    gen_mini_matrix()
    print('Done.')
