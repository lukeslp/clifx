#!/usr/bin/env bats
# ============================================================================
# tests/test_box_progress.bats — Unit tests for lib/box.sh and lib/progress.sh
# Run: bats tests/test_box_progress.bats
# ============================================================================

load helpers/setup

setup() {
    source_lib style terminal text animation progress box divider
    source_theme default
    TERM_COLS=80
    TERM_ROWS=24
    CONTENT_WIDTH=80
}

# ---------------------------------------------------------------------------
# draw_box
# ---------------------------------------------------------------------------

@test "draw_box: runs without error for single style" {
    run draw_box 20 5 single
    [ "$status" -eq 0 ]
}

@test "draw_box: runs without error for all border styles" {
    for style in single double rounded heavy; do
        run draw_box 20 5 "$style"
        [ "$status" -eq 0 ]
    done
}

@test "draw_box: output has correct number of lines" {
    result=$(draw_box 20 5 single)
    # wc -l counts newlines; a 5-row box has 5 newlines
    count=$(printf '%s' "$result" | wc -l)
    [ "$count" -ge 4 ] && [ "$count" -le 5 ]
}

# ---------------------------------------------------------------------------
# draw_box_text
# ---------------------------------------------------------------------------

@test "draw_box_text: runs without error" {
    run draw_box_text "hello world" single
    [ "$status" -eq 0 ]
}

@test "draw_box_text: output contains the input text" {
    result=$(draw_box_text "test content" single)
    stripped=$(strip_ansi "$result")
    [[ "$stripped" == *"test content"* ]]
}

@test "draw_box_text: multi-line text is boxed correctly" {
    run draw_box_text $'line one\nline two' rounded
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# draw_header
# ---------------------------------------------------------------------------

@test "draw_header: runs without error" {
    run draw_header "Section Title" thick
    [ "$status" -eq 0 ]
}

@test "draw_header: output contains the title text" {
    result=$(draw_header "My Header" single)
    stripped=$(strip_ansi "$result")
    [[ "$stripped" == *"My Header"* ]]
}

# ---------------------------------------------------------------------------
# progress_bar
# ---------------------------------------------------------------------------

@test "progress_bar: runs without error at 0%" {
    run progress_bar 0 100 30
    [ "$status" -eq 0 ]
}

@test "progress_bar: runs without error at 100%" {
    run progress_bar 100 100 30
    [ "$status" -eq 0 ]
}

@test "progress_bar: output contains percentage" {
    result=$(progress_bar 50 100 30)
    stripped=$(strip_ansi "$result")
    [[ "$stripped" == *"50%"* ]]
}

# ---------------------------------------------------------------------------
# checklist_item
# ---------------------------------------------------------------------------

@test "checklist_item: done status runs without error" {
    run checklist_item "Task complete" done
    [ "$status" -eq 0 ]
}

@test "checklist_item: fail status runs without error" {
    run checklist_item "Task failed" fail
    [ "$status" -eq 0 ]
}

@test "checklist_item: pending status runs without error" {
    run checklist_item "Task pending" pending
    [ "$status" -eq 0 ]
}

@test "checklist_item: output contains the message" {
    result=$(checklist_item "my task" done)
    stripped=$(strip_ansi "$result")
    [[ "$stripped" == *"my task"* ]]
}

# ---------------------------------------------------------------------------
# divider
# ---------------------------------------------------------------------------

@test "divider: all six styles run without error" {
    for style in thin thick double dotted dashed wave; do
        run divider "$style"
        [ "$status" -eq 0 ]
    done
}
