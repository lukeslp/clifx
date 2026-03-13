#!/usr/bin/env bats
# ============================================================================
# tests/test_effects_smoke.bats — Smoke tests for all effect manifests
#
# These tests verify that every effect function can be invoked without
# crashing. They do NOT verify visual output — that requires a human.
# All effects run with CLIFX_SPEED_MULT=1 to complete near-instantly.
# Run: bats tests/test_effects_smoke.bats
# ============================================================================

load helpers/setup

setup() {
    source_lib style terminal text animation ascii progress box divider corruption
    source_theme default
    TERM_COLS=80
    TERM_ROWS=24
    COLS=80
    ROWS=24
    export CLIFX_SPEED_MULT=1

    # manifest.sh has a top-level case dispatch that runs when sourced.
    # We extract only the function definitions by sourcing with a guard.
    # Strategy: source with arg 'help' (safe no-op) to get function defs.
    set -- help  # set $1 to 'help' so the case runs the help branch
    source "$CLIFX_ROOT/scripts/manifest.sh" 2>/dev/null || true
    set --       # clear positional parameters
    # Also source sub-manifests for physics, data, hybrid
    for _ef in "$CLIFX_ROOT"/scripts/manifest_*.sh; do
        [ -f "$_ef" ] && source "$_ef" 2>/dev/null || true
    done
}

# ---------------------------------------------------------------------------
# Core effects
# ---------------------------------------------------------------------------

@test "effect_glitch: runs without error" {
    run effect_glitch 1 1
    [ "$status" -eq 0 ]
}

@test "effect_static: runs without error" {
    run effect_static 1
    [ "$status" -eq 0 ]
}

@test "effect_flicker: runs without error" {
    run effect_flicker 2
    [ "$status" -eq 0 ]
}

@test "effect_styled_frame: runs without error" {
    run effect_styled_frame "test"
    [ "$status" -eq 0 ]
}

@test "effect_build_text: runs without error" {
    run effect_build_text "hello" 1
    [ "$status" -eq 0 ]
}

@test "effect_heartbeat: runs without error" {
    run effect_heartbeat 1 "◈"
    [ "$status" -eq 0 ]
}

@test "effect_transition: runs without error" {
    run effect_transition
    [ "$status" -eq 0 ]
}

@test "effect_color_wave: runs without error" {
    run effect_color_wave 1 down
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Corruption effects
# ---------------------------------------------------------------------------

@test "effect_screen_tear: runs without error" {
    run effect_screen_tear 1 1
    [ "$status" -eq 0 ]
}

@test "effect_scanlines: runs without error" {
    run effect_scanlines 1 1
    [ "$status" -eq 0 ]
}

@test "effect_chromatic_aberration: runs without error" {
    run effect_chromatic_aberration "test" 1
    [ "$status" -eq 0 ]
}

@test "effect_signal_noise: runs without error" {
    run effect_signal_noise 1 1 1
    [ "$status" -eq 0 ]
}

@test "effect_datamosh: runs without error" {
    run effect_datamosh 1 1
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Spatial effects
# ---------------------------------------------------------------------------

@test "effect_rain: runs without error" {
    run effect_rain 1 10
    [ "$status" -eq 0 ]
}

@test "effect_ripple: runs without error" {
    run effect_ripple 1 1
    [ "$status" -eq 0 ]
}

@test "effect_orbit: runs without error" {
    run effect_orbit 1 1 "@"
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Theater effects
# ---------------------------------------------------------------------------

@test "effect_hex_dump: runs without error" {
    run effect_hex_dump 5 1
    [ "$status" -eq 0 ]
}

@test "effect_waveform: runs without error" {
    run effect_waveform 1 1
    [ "$status" -eq 0 ]
}

@test "effect_process_tree: runs without error" {
    run effect_process_tree 1
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Atmosphere effects
# ---------------------------------------------------------------------------

@test "effect_afterimage: runs without error" {
    run effect_afterimage "test"
    [ "$status" -eq 0 ]
}

@test "effect_typewriter_rewind: runs without error" {
    run effect_typewriter_rewind "hello" "world" 1
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Physics effects (new)
# ---------------------------------------------------------------------------

@test "effect_particles: runs without error" {
    [ -f "$CLIFX_ROOT/scripts/manifest_physics.sh" ] || skip "manifest_physics.sh not found"
    source "$CLIFX_ROOT/scripts/manifest_physics.sh"
    run effect_particles 1 5
    [ "$status" -eq 0 ]
}

@test "effect_gravity_text: runs without error" {
    [ -f "$CLIFX_ROOT/scripts/manifest_physics.sh" ] || skip "manifest_physics.sh not found"
    source "$CLIFX_ROOT/scripts/manifest_physics.sh"
    run effect_gravity_text "hello"
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Data effects (new)
# ---------------------------------------------------------------------------

@test "effect_cpu_sparkline: runs without error" {
    [ -f "$CLIFX_ROOT/scripts/manifest_data.sh" ] || skip "manifest_data.sh not found"
    source "$CLIFX_ROOT/scripts/manifest_data.sh"
    run effect_cpu_sparkline 3 1
    [ "$status" -eq 0 ]
}

@test "effect_disk_bars: runs without error" {
    [ -f "$CLIFX_ROOT/scripts/manifest_data.sh" ] || skip "manifest_data.sh not found"
    source "$CLIFX_ROOT/scripts/manifest_data.sh"
    run effect_disk_bars
    [ "$status" -eq 0 ]
}
