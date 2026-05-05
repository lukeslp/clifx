# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

**clifx** is a pure Bash terminal visual effects library. It provides building blocks for character-by-character text rendering, full-screen animations, glitch/corruption effects, and themed text styling — designed for interactive terminal experiences, games, and CLI tools.

No build step. No dependencies beyond Bash 4+ and a terminal that supports 256-color ANSI.

## Running

```bash
# Top-level CLI (interactive TUI when run with no args)
./clifx

# Run a specific effect
./clifx <effect_name> [args...]
./clifx rain 5 15
./clifx chromatic_aberration "SIGNAL LOST" 3

# Voice/text rendering
./clifx voice "message" shout

# Play a frame animation (auto-constrained to terminal viewport)
./clifx play gears 24 0

# List all effects, voices, and animations
./clifx list

# Interactive widgets (counter, cursor, paint)
./clifx interactive counter

# Lower-level scripts (still work, used internally by ./clifx)
bash scripts/manifest.sh <effect_name> [args...]
bash scripts/voice.sh "message" [whisper|speak|shout|corrupt|fragment|clear]
bash scripts/play.sh ascii-animations/spiral.txt 12
bash scripts/interactive.sh paint "░"
```

## Testing

Bats test suite in `tests/`. Requires `bats-core` (`apt install bats` or `npm i -g bats`).

```bash
bats tests/                          # run all suites
bats tests/test_ascii.bats           # single suite
bats -f "strip_ansi" tests/          # filter by test name pattern
```

`tests/helpers/setup.bash` sources `lib/core.sh` with a headless `TERM=xterm-256color`, `COLUMNS=80`, `LINES=24`, and pins `CLIFX_SPEED_MULT=1` so effects never actually sleep. New test files should `load "helpers/setup"` first.

## Speed Control

Set `CLIFX_SPEED_MULT` env var (percentage: 50 = 2x faster, 200 = 2x slower). All timing goes through `sleep_ms()` in `lib/core.sh`, which honors this multiplier.

## Animation Size Control

Animations come in two sizes:
- **Compact** (`mini-*`): 30-36w x 14-18h — fit standard 80x24 terminals
- **Full-size**: 100-160w x 51-81h — need large terminals or get center-cropped

Force a max viewport with env vars:
```bash
CLIFX_MAX_WIDTH=40 CLIFX_MAX_HEIGHT=20 ./clifx play gears 24 1
```
These constrain `_crop_frame()` independently of terminal size. The frame is center-cropped to fit.

## GIF/Video to Terminal Converter

Convert GIF or video files to colored terminal animations using Unicode half-block characters (`▀`) with true-color ANSI. Each character cell renders 2 vertical pixels.

```bash
# Convert a GIF (game-ready: 40x20 chars)
./clifx convert explosion.gif -w 40 -ht 20

# Convert with custom name and preview
./clifx convert cutscene.gif -o intro --preview

# Video files work too (uses ffmpeg)
./clifx convert clip.mp4 -w 50 -ht 25 --max-frames 60

# Tiny sprite with dithering
./clifx convert sprite.gif -w 16 -ht 8 --dither
```

Output lands in `ascii-animations/` as `term-<name>.txt`, playable via `./clifx play`.

Requires: Python 3, Pillow (`pip install Pillow`), ffmpeg (for video files).

## Architecture

### Source Order Matters

`lib/core.sh` must be sourced first — it sets up `CLIFX_LIB_DIR`, terminal dimensions, `sleep_ms()`, and the `source_lib`/`source_theme` loader functions. All other lib files use include guards (`_CLIFX_*_LOADED`).

```
clifx                ← top-level CLI: interactive TUI (no args) or direct commands
│
lib/core.sh          ← source this first (bootstrap, constants, sleep_ms, source_lib)
├── lib/style.sh     ← ANSI codes, color constructors (fg, bg, fg_rgb), capability detection
├── lib/terminal.sh  ← cursor movement, screen clearing, centering math
├── lib/text.sh      ← type_text, center_text, pad_text, wrap_text, indent
├── lib/animation.sh ← sweep, pulse, flash_screen, fill_random, clear_sweep
├── lib/progress.sh  ← spinner, progress_bar, fake_progress, checklist_item
├── lib/box.sh       ← draw_box, draw_box_text, draw_header, draw_panel (4 border styles)
├── lib/divider.sh   ← divider, divider_text, blank_lines (6 line styles)
├── lib/corruption.sh← corrupted install sequences, glitch_wash, RTL rendering, script_freeze
├── lib/ascii.sh     ← render_art, render_art_animated, assemble_fragments, play_frames (+viewport crop)
│
theme/default.sh     ← default color palette + frame characters (overridable via CLIFX_COLOR_*)
│
ascii-animations/    ← frame-delimited animation files (.txt) — spiral, gears, cube, bauhaus, ironman
│
scripts/manifest.sh          ← effect dispatcher (auto-sources every scripts/manifest_*.sh on startup)
├── scripts/manifest_corruption.sh ← screen_tear, scanlines, chromatic_aberration, signal_noise, datamosh
├── scripts/manifest_spatial.sh    ← rain, spiral, ripple, orbit
├── scripts/manifest_theater.sh    ← hex_dump, waveform, process_tree
├── scripts/manifest_atmosphere.sh ← vignette, plasma, breathe, afterimage, typewriter_rewind
├── scripts/manifest_data.sh       ← cpu_sparkline, mem_bars, disk_bars, net_monitor, proc_heatmap, sysinfo_panel (⚠ not yet dispatched)
├── scripts/manifest_physics.sh    ← particles, gravity_text, explosion, fountain, shockwave (⚠ not yet dispatched)
└── scripts/manifest_hybrid.sh     ← plasma_hd, rain_hd — Python-accelerated via tools/effects/*.py, fall back to Bash (⚠ not yet dispatched)
│
scripts/voice.sh         ← text voice renderer (whisper, speak, shout, corrupt, fragment, clear)
scripts/play.sh          ← standalone frame animation player (wraps play_frames with trap/cleanup)
scripts/interactive.sh   ← iloop_* widget launcher (counter, cursor, paint) — wired to `./clifx interactive`
scripts/tester.sh        ← legacy interactive tester (superseded by ./clifx)
│
tools/gif2term.py        ← GIF/video to terminal converter (Python 3 + Pillow)
tools/gen_small_anims.py ← generator for procedural compact animations
tools/effects/           ← Python helpers used by manifest_hybrid.sh (plasma.py, rain.py)
│
tests/                   ← Bats suite; load helpers/setup.bash for headless TERM + CLIFX_SPEED_MULT=1
demos/record.sh          ← script that renders SVG demo reels (demos/*.svg) via terminal-to-svg capture
```

### ⚠ Unwired Effect Modules

`manifest_data.sh`, `manifest_physics.sh`, and `manifest_hybrid.sh` are auto-sourced by the `for _ef in manifest_*.sh` loop, so their `effect_*` functions are **defined** but there is no `case` entry in `scripts/manifest.sh` and no `EFFECTS_*` array in `clifx` referencing them. To expose one of these effects end-to-end you must:

1. Add a `case` arm in `scripts/manifest.sh` mapping the effect name to its function
2. Add the name to an `EFFECTS_*` array in `clifx` (or create a new category array and append to `ALL_EFFECTS`)
3. Add a `run_effect()` case arm in `clifx`

Calling `./clifx particles` today falls through to the "unknown effect" branch even though `effect_particles` exists.

### How to Source the Library

From any script:
```bash
source "path/to/lib/core.sh"
source_lib style terminal text animation  # load specific modules
source_theme default                       # load default color theme
```

### Theme System

Theme colors are overridable via env vars (`CLIFX_COLOR_FG`, `CLIFX_COLOR_GLOW`, `CLIFX_COLOR_DIM`, `CLIFX_COLOR_ACCENT`). The tester uses this to preview effects in different color schemes. Theme files live in `theme/` and are loaded via `source_theme`.

Theme vars: `THEME_FG`, `THEME_DIM`, `THEME_GLOW`, `THEME_ACCENT`, `THEME_WARN`, `THEME_BG`.

### Effect Categories (28 effects + frame player)

| Category | File | Effects |
|----------|------|---------|
| Core | `manifest.sh` | glitch, static, flicker, styled_frame, build_text, corruption, heartbeat, transition, color_wave, fake_install, credits |
| Corruption | `manifest_corruption.sh` | screen_tear, scanlines, chromatic_aberration, signal_noise, datamosh |
| Spatial | `manifest_spatial.sh` | rain, spiral, ripple, orbit |
| Theater | `manifest_theater.sh` | hex_dump, waveform, process_tree |
| Atmosphere | `manifest_atmosphere.sh` | vignette, plasma, breathe, afterimage, typewriter_rewind |
| Animation | `manifest.sh` (play) | play (frame animation from .txt files) |

### Adding New Effects

1. Pick the right `manifest_*.sh` module (or create a new one following the naming pattern)
2. Add an include guard at the top: `[[ -n "${_CLIFX_MANIFEST_YOURMODULE_LOADED:-}" ]] && return 0`
3. Define `effect_yourname()` — use `hide_cursor`/`show_cursor`, reference `ROWS`/`COLS`
4. Add a dispatch entry in `manifest.sh`'s `case` block and `help` output
5. Add to `clifx`'s `ALL_EFFECTS` array and `run_effect()` case block (for interactive TUI + direct CLI)

### Adding New Animations

Drop a `--- Frame N ---` delimited `.txt` file into `ascii-animations/`. The `./clifx` TUI auto-discovers it. Frames are automatically center-cropped to fit the terminal viewport via `_crop_frame()` in `lib/ascii.sh`.

Naming convention determines TUI grouping:
- `mini-*` — compact procedural animations (grouped under "compact")
- `term-*` — converted from GIF/video via `gif2term.py`, contain ANSI color codes (also "compact")
- Everything else — "full-size" category

### Animation File Types

There are two distinct formats in `ascii-animations/`:

1. **Plain ASCII** (all `mini-*` and full-size files): printable characters only, measured and cropped by character count
2. **ANSI-colored** (`term-*` files from converter): contain `\033[38;2;R;G;Bm` true-color escapes for half-block rendering

`_crop_frame()` in `lib/ascii.sh` detects ANSI content and skips horizontal cropping (substring ops would break escape sequences). Vertical cropping still works. When measuring width, ANSI codes are stripped via `_strip_ansi()` before counting.

### Key Conventions

- All timing uses `sleep_ms` (never raw `sleep` for sub-second delays) — this ensures speed multiplier works
- Effects must call `hide_cursor` at start and `show_cursor` before return
- Terminal dimensions: use `ROWS` and `COLS` (aliased from `TERM_ROWS`/`TERM_COLS`)
- Theme colors: use `THEME_FG`, `THEME_DIM`, `THEME_GLOW`, `THEME_ACCENT`, `THEME_WARN` from current theme
- Frame characters come from `FRAME_CHAR_SET` array; use `random_frame_char()` to pick one
- `manifest_*.sh` files are sourced by `manifest.sh` — they should not be run directly
- The `clifx` CLI dispatches via a `case` block: `voice`, `play`, `convert`, `list`, `help` are named commands; anything else is tried as an effect name via `run_effect()`
- The TUI animation menu displays in a custom order (compact first, then full-size) using `_anim_order` index mapping — selection numbers don't map 1:1 to `ANIM_NAMES` array indices
