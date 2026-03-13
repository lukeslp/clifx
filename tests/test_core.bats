#!/usr/bin/env bats
# ============================================================================
# tests/test_core.bats — Unit tests for lib/core.sh
# Run: bats tests/test_core.bats
# ============================================================================

load helpers/setup

# ---------------------------------------------------------------------------
# sleep_ms
# ---------------------------------------------------------------------------

@test "sleep_ms: completes without error for 1ms" {
    run sleep_ms 1
    [ "$status" -eq 0 ]
}

@test "sleep_ms: respects CLIFX_SPEED_MULT=1 (near-instant)" {
    export CLIFX_SPEED_MULT=1
    local start=$SECONDS
    sleep_ms 500
    local elapsed=$(( SECONDS - start ))
    # With 1% speed, 500ms becomes ~5ms — should finish in well under 1 second
    [ "$elapsed" -lt 2 ]
}

@test "sleep_ms: clamps to minimum 1ms when multiplied to zero" {
    export CLIFX_SPEED_MULT=1
    run sleep_ms 0
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# random_int
# ---------------------------------------------------------------------------

@test "random_int: returns a value within [min, max]" {
    for i in $(seq 1 20); do
        val=$(random_int 5 10)
        [ "$val" -ge 5 ]
        [ "$val" -le 10 ]
    done
}

@test "random_int: works when min == max" {
    val=$(random_int 7 7)
    [ "$val" -eq 7 ]
}

@test "random_int: returns integer output" {
    val=$(random_int 1 100)
    [[ "$val" =~ ^[0-9]+$ ]]
}

# ---------------------------------------------------------------------------
# random_choice
# ---------------------------------------------------------------------------

@test "random_choice: returns one of the provided values" {
    local arr=("alpha" "beta" "gamma")
    for i in $(seq 1 20); do
        result=$(random_choice "${arr[@]}")
        [[ "$result" == "alpha" || "$result" == "beta" || "$result" == "gamma" ]]
    done
}

@test "random_choice: works with a single element" {
    result=$(random_choice "only")
    [ "$result" = "only" ]
}

# ---------------------------------------------------------------------------
# source_lib
# ---------------------------------------------------------------------------

@test "source_lib: loads style module successfully" {
    run source_lib style
    [ "$status" -eq 0 ]
}

@test "source_lib: loads multiple modules successfully" {
    run source_lib style terminal text
    [ "$status" -eq 0 ]
}

@test "source_lib: fails gracefully for missing module" {
    run source_lib nonexistent_module_xyz
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

# ---------------------------------------------------------------------------
# source_theme
# ---------------------------------------------------------------------------

@test "source_theme: loads default theme successfully" {
    run source_theme default
    [ "$status" -eq 0 ]
}

@test "source_theme: fails gracefully for missing theme" {
    run source_theme nonexistent_theme_xyz
    [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# CLIFX_LIB_DIR and CLIFX_ROOT_DIR
# ---------------------------------------------------------------------------

@test "CLIFX_LIB_DIR: is set and points to a real directory" {
    [ -d "$CLIFX_LIB_DIR" ]
}

@test "CLIFX_ROOT_DIR: is set and points to a real directory" {
    [ -d "$CLIFX_ROOT_DIR" ]
}

@test "CLIFX_ROOT_DIR: contains the clifx CLI entry point" {
    [ -f "$CLIFX_ROOT_DIR/clifx" ]
}
