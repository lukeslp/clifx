#!/usr/bin/env bats
# ============================================================================
# tests/test_ascii.bats — Unit tests for lib/ascii.sh
# Run: bats tests/test_ascii.bats
# ============================================================================

load helpers/setup

setup() {
    source_lib style terminal ascii
    source_theme default
    TERM_COLS=80
    TERM_ROWS=24
}

# ---------------------------------------------------------------------------
# _strip_ansi
# ---------------------------------------------------------------------------

@test "_strip_ansi: removes color codes from string" {
    input=$'\033[38;5;48mhello\033[0m'
    result=$(_strip_ansi "$input")
    [ "$result" = "hello" ]
}

@test "_strip_ansi: passes plain text through unchanged" {
    result=$(_strip_ansi "plain text")
    [ "$result" = "plain text" ]
}

# ---------------------------------------------------------------------------
# render_art
# ---------------------------------------------------------------------------

@test "render_art: renders a simple string without error" {
    run render_art "hello world"
    [ "$status" -eq 0 ]
}

@test "render_art: output contains the input text" {
    result=$(render_art "test art")
    stripped=$(strip_ansi "$result")
    [[ "$stripped" == *"test art"* ]]
}

@test "render_art: renders multi-line art" {
    art=$'line1\nline2\nline3'
    result=$(render_art "$art")
    # Output should contain all three lines
    [[ "$result" == *"line1"* ]]
    [[ "$result" == *"line2"* ]]
    [[ "$result" == *"line3"* ]]
}

# ---------------------------------------------------------------------------
# _crop_frame
# ---------------------------------------------------------------------------

@test "_crop_frame: returns content within viewport bounds" {
    TERM_COLS=40
    TERM_ROWS=10
    # Build a frame wider and taller than the viewport
    frame=""
    for i in $(seq 1 20); do
        frame+="$(printf '%0.s#' {1..80})"$'\n'
    done
    result=$(_crop_frame "$frame")
    while IFS= read -r line; do
        stripped=$(strip_ansi "$line")
        [ "${#stripped}" -le 40 ]
    done <<< "$result"
}

@test "_crop_frame: handles empty frame without error" {
    run _crop_frame ""
    [ "$status" -eq 0 ]
}

@test "_crop_frame: respects CLIFX_MAX_WIDTH override" {
    TERM_COLS=80
    export CLIFX_MAX_WIDTH=20
    frame="$(printf '%0.s#' {1..80})"
    result=$(_crop_frame "$frame")
    stripped=$(strip_ansi "$result")
    [ "${#stripped}" -le 20 ]
    unset CLIFX_MAX_WIDTH
}

# ---------------------------------------------------------------------------
# play_frames (smoke test — just verify it doesn't crash on a real file)
# ---------------------------------------------------------------------------

@test "play_frames: plays mini-spinner for 1 loop without error" {
    local anim_file="$CLIFX_ROOT/ascii-animations/mini-spinner.txt"
    [ -f "$anim_file" ] || skip "mini-spinner.txt not found"
    run play_frames "$anim_file" 60 1
    [ "$status" -eq 0 ]
}

@test "play_frames: returns error for missing file" {
    run play_frames "/nonexistent/path/anim.txt" 12 1
    [ "$status" -ne 0 ]
}

@test "play_frames: returns error for file with no frames" {
    local tmp
    tmp=$(mktemp /tmp/clifx_test_XXXX.txt)
    echo "no frame delimiters here" > "$tmp"
    run play_frames "$tmp" 12 1
    [ "$status" -ne 0 ]
    rm -f "$tmp"
}
