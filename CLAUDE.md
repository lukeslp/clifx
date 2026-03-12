# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

**clifx** is a pure Bash terminal visual effects library. It provides building blocks for character-by-character text rendering, full-screen animations, glitch/corruption effects, and themed text styling — designed for interactive terminal experiences, games, and CLI tools.

No build step. No dependencies beyond Bash 4+ and a terminal that supports 256-color ANSI.

## Running

```bash
# Run a specific effect
bash scripts/manifest.sh <effect_name> [args...]

# Interactive tester with speed/color controls
bash scripts/tester.sh

# Voice/text rendering
bash scripts/voice.sh "message" [whisper|speak|shout|corrupt|fragment|clear]

# List all available effects
bash scripts/manifest.sh help
```

## Speed Control

Set `CLIFX_SPEED_MULT` env var (percentage: 50 = 2x faster, 200 = 2x slower). All timing goes through `sleep_ms()` in `lib/core.sh`, which honors this multiplier.

## Architecture

### Source Order Matters

`lib/core.sh` must be sourced first — it sets up `CLIFX_LIB_DIR`, terminal dimensions, `sleep_ms()`, and the `source_lib`/`source_theme` loader functions. All other lib files use include guards (`_CLIFX_*_LOADED`).

```
lib/core.sh          ← source this first (bootstrap, constants, sleep_ms, source_lib)
├── lib/style.sh     ← ANSI codes, color constructors (fg, bg, fg_rgb), capability detection
├── lib/terminal.sh  ← cursor movement, screen clearing, centering math
├── lib/text.sh      ← type_text, center_text, pad_text, wrap_text, indent
├── lib/animation.sh ← sweep, pulse, flash_screen, fill_random, clear_sweep
├── lib/progress.sh  ← spinner, progress_bar, fake_progress, checklist_item
├── lib/box.sh       ← draw_box, draw_box_text, draw_header, draw_panel (4 border styles)
├── lib/divider.sh   ← divider, divider_text, blank_lines (6 line styles)
├── lib/corruption.sh← corrupted install sequences, glitch_wash, RTL rendering, script_freeze
├── lib/ascii.sh     ← render_art, render_art_animated, assemble_fragments
│
theme/default.sh     ← default color palette + frame characters (overridable via CLIFX_COLOR_*)
│
scripts/manifest.sh          ← effect dispatcher (sources all manifest_*.sh modules)
├── scripts/manifest_corruption.sh ← screen_tear, scanlines, chromatic_aberration, signal_noise, datamosh
├── scripts/manifest_spatial.sh    ← rain, spiral, ripple, orbit
├── scripts/manifest_theater.sh    ← hex_dump, waveform, process_tree
├── scripts/manifest_atmosphere.sh ← vignette, plasma, breathe, afterimage, typewriter_rewind
│
scripts/voice.sh     ← text voice renderer (whisper, speak, shout, corrupt, fragment, clear)
scripts/tester.sh    ← interactive TUI for testing all effects with speed/color overrides
```

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

### Effect Categories (26 total)

| Category | File | Effects |
|----------|------|---------|
| Core | `manifest.sh` | glitch, static, flicker, styled_frame, build_text, corruption, heartbeat, transition, color_wave, fake_install, credits |
| Corruption | `manifest_corruption.sh` | screen_tear, scanlines, chromatic_aberration, signal_noise, datamosh |
| Spatial | `manifest_spatial.sh` | rain, spiral, ripple, orbit |
| Theater | `manifest_theater.sh` | hex_dump, waveform, process_tree |
| Atmosphere | `manifest_atmosphere.sh` | vignette, plasma, breathe, afterimage, typewriter_rewind |

### Adding New Effects

1. Pick the right `manifest_*.sh` module (or create a new one following the naming pattern)
2. Add an include guard at the top: `[[ -n "${_CLIFX_MANIFEST_YOURMODULE_LOADED:-}" ]] && return 0`
3. Define `effect_yourname()` — use `hide_cursor`/`show_cursor`, reference `ROWS`/`COLS`
4. Add a dispatch entry in `manifest.sh`'s `case` block and `help` output
5. Add to `tester.sh`'s effect arrays and `run_effect()` case block

### Key Conventions

- All timing uses `sleep_ms` (never raw `sleep` for sub-second delays) — this ensures speed multiplier works
- Effects must call `hide_cursor` at start and `show_cursor` before return
- Terminal dimensions: use `ROWS` and `COLS` (aliased from `TERM_ROWS`/`TERM_COLS`)
- Theme colors: use `THEME_FG`, `THEME_DIM`, `THEME_GLOW`, `THEME_ACCENT`, `THEME_WARN` from current theme
- Frame characters come from `FRAME_CHAR_SET` array; use `random_frame_char()` to pick one
- `manifest_*.sh` files are sourced by `manifest.sh` — they should not be run directly
