#!/usr/bin/env bats
# ============================================================================
# tests/test_style.bats — Unit tests for lib/style.sh
# Run: bats tests/test_style.bats
# ============================================================================

load helpers/setup

setup() {
    source_lib style
}

# ---------------------------------------------------------------------------
# fg / bg
# ---------------------------------------------------------------------------

@test "fg: returns a non-empty ANSI escape string" {
    result=$(fg 196)
    [ -n "$result" ]
    [[ "$result" == *"196"* ]]
}

@test "bg: returns a non-empty ANSI escape string" {
    result=$(bg 21)
    [ -n "$result" ]
    [[ "$result" == *"21"* ]]
}

@test "fg: output contains ESC character" {
    result=$(fg 48)
    [[ "$result" == $'\033'* ]]
}

# ---------------------------------------------------------------------------
# fg_rgb / bg_rgb
# ---------------------------------------------------------------------------

@test "fg_rgb: returns a non-empty ANSI escape for R G B input" {
    result=$(fg_rgb 255 128 0)
    [ -n "$result" ]
    [[ "$result" == $'\033'* ]]
}

@test "bg_rgb: returns a non-empty ANSI escape for R G B input" {
    result=$(bg_rgb 10 20 30)
    [ -n "$result" ]
    [[ "$result" == $'\033'* ]]
}

@test "fg_rgb: output starts with ESC" {
    result=$(fg_rgb 100 200 50)
    [[ "$result" == $'\033'* ]]
}

# ---------------------------------------------------------------------------
# style_reset
# ---------------------------------------------------------------------------

@test "style_reset: returns a non-empty reset sequence" {
    result=$(style_reset)
    [ -n "$result" ]
    [[ "$result" == $'\033'* ]]
}

# ---------------------------------------------------------------------------
# Terminal capability detection
# ---------------------------------------------------------------------------

@test "supports_256_color: returns 0 or 1 without error" {
    run supports_256_color
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "supports_truecolor: returns 0 or 1 without error" {
    run supports_truecolor
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}
