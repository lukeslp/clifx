#!/usr/bin/env bats
# ============================================================================
# tests/test_theme.bats — Unit tests for theme system and theme_generator.sh
# Run: bats tests/test_theme.bats
# ============================================================================

load helpers/setup

setup() {
    source_lib style terminal
    source_theme default
}

# ---------------------------------------------------------------------------
# Default theme variables
# ---------------------------------------------------------------------------

@test "default theme: THEME_FG is set and non-empty" {
    [ -n "$THEME_FG" ]
}

@test "default theme: THEME_DIM is set and non-empty" {
    [ -n "$THEME_DIM" ]
}

@test "default theme: THEME_GLOW is set and non-empty" {
    [ -n "$THEME_GLOW" ]
}

@test "default theme: THEME_ACCENT is set and non-empty" {
    [ -n "$THEME_ACCENT" ]
}

@test "default theme: THEME_WARN is set and non-empty" {
    [ -n "$THEME_WARN" ]
}

@test "default theme: FRAME_CHAR_SET is a non-empty array" {
    [ "${#FRAME_CHAR_SET[@]}" -gt 0 ]
}

# ---------------------------------------------------------------------------
# CLIFX_COLOR_* env var overrides
# ---------------------------------------------------------------------------

@test "theme: CLIFX_COLOR_FG overrides THEME_FG" {
    export CLIFX_COLOR_FG='\033[38;5;196m'
    # Re-source theme to pick up override
    _CLIFX_THEME_DEFAULT_LOADED=""
    source_theme default
    [ "$THEME_FG" = '\033[38;5;196m' ]
    unset CLIFX_COLOR_FG
    _CLIFX_THEME_DEFAULT_LOADED=""
    source_theme default
}

# ---------------------------------------------------------------------------
# theme_generator.sh
# ---------------------------------------------------------------------------

@test "theme_generator: script exists and is executable" {
    [ -f "$CLIFX_ROOT/tools/theme_generator.sh" ]
    [ -x "$CLIFX_ROOT/tools/theme_generator.sh" ]
}

@test "theme_generator: generates a valid theme file from a base color" {
    local out
    out=$(bash "$CLIFX_ROOT/tools/theme_generator.sh" 48 2>/dev/null)
    [ -n "$out" ]
    [[ "$out" == *"THEME_FG"* ]]
    [[ "$out" == *"THEME_DIM"* ]]
    [[ "$out" == *"THEME_GLOW"* ]]
    [[ "$out" == *"THEME_ACCENT"* ]]
}

@test "theme_generator: --save writes a file to theme/" {
    bash "$CLIFX_ROOT/tools/theme_generator.sh" 196 --save test_generated 2>/dev/null
    [ -f "$CLIFX_ROOT/theme/test_generated.sh" ]
    rm -f "$CLIFX_ROOT/theme/test_generated.sh"
}

@test "theme_generator: generated theme is sourceable" {
    bash "$CLIFX_ROOT/tools/theme_generator.sh" 33 --save _bats_tmp 2>/dev/null
    run source "$CLIFX_ROOT/theme/_bats_tmp.sh"
    [ "$status" -eq 0 ]
    rm -f "$CLIFX_ROOT/theme/_bats_tmp.sh"
}
