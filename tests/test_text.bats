#!/usr/bin/env bats
# ============================================================================
# tests/test_text.bats — Unit tests for lib/text.sh
# Run: bats tests/test_text.bats
# ============================================================================

load helpers/setup

setup() {
    source_lib style terminal text
    source_theme default
    TERM_COLS=80
    TERM_ROWS=24
}

# ---------------------------------------------------------------------------
# truncate_text
# ---------------------------------------------------------------------------

@test "truncate_text: returns string unchanged when shorter than limit" {
    result=$(truncate_text "hello" 20)
    [ "$result" = "hello" ]
}

@test "truncate_text: truncates to specified width" {
    result=$(truncate_text "hello world" 5 "...")
    stripped=$(strip_ansi "$result")
    [ "${#stripped}" -le 8 ]   # 5 chars + 3 for "..."
}

@test "truncate_text: appends ellipsis when truncating" {
    result=$(truncate_text "abcdefghij" 5 "...")
    [[ "$result" == *"..."* ]]
}

# ---------------------------------------------------------------------------
# wrap_text
# ---------------------------------------------------------------------------

@test "wrap_text: wraps long lines at word boundaries" {
    long="the quick brown fox jumps over the lazy dog and keeps on running"
    result=$(wrap_text "$long" 20)
    # Each line should be at most 20 chars
    while IFS= read -r line; do
        [ "${#line}" -le 20 ]
    done <<< "$result"
}

@test "wrap_text: short string passes through unchanged" {
    result=$(wrap_text "hello" 80)
    [[ "$result" == *"hello"* ]]
}

# ---------------------------------------------------------------------------
# pad_text
# ---------------------------------------------------------------------------

@test "pad_text: pads string to specified width" {
    result=$(pad_text "hi" 10)
    [ "${#result}" -ge 10 ]
}

# ---------------------------------------------------------------------------
# center_text (output test — just verify it runs)
# ---------------------------------------------------------------------------

@test "center_text: runs without error" {
    run center_text "hello"
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# type_text (output test)
# ---------------------------------------------------------------------------

@test "type_text: runs without error" {
    run type_text "hello" 1
    [ "$status" -eq 0 ]
}

@test "type_text: output contains the input text" {
    result=$(type_text "hello world" 1)
    stripped=$(strip_ansi "$result")
    [[ "$stripped" == *"hello world"* ]]
}
