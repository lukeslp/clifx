#!/usr/bin/env bats
# ============================================================================
# tests/game/test_voice_bridge.bats — entity voice mode selection + dispatch
# Visual rendering is exercised but not asserted on exact output — bats is
# headless, and clifx voices rely on escape codes. We assert that each mode
# runs to completion without error and produces non-empty stdout.
# ============================================================================

setup() {
    CLIFX_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    VOICE_SH="$CLIFX_ROOT/game/engine/voice.sh"
    STATE_SH="$CLIFX_ROOT/game/engine/state.sh"

    TEST_TMP="$(mktemp -d -t clifx-voice.XXXXXX)"
    export CLIFX_GAME_DIR="$TEST_TMP"
    export CLIFX_GAME_STATE_FILE="$TEST_TMP/var/state.json"
    export CLIFX_GAME_STATE_SH="$STATE_SH"
    mkdir -p "$TEST_TMP/var"

    # Skip real sleeps so tests run fast
    export CLIFX_SPEED_MULT=1

    # Provide headless terminal env for clifx
    export TERM="${TERM:-xterm-256color}"
    export COLUMNS="${COLUMNS:-80}"
    export LINES="${LINES:-24}"
}

teardown() {
    [ -n "${TEST_TMP:-}" ] && [ -d "$TEST_TMP" ] && rm -rf "$TEST_TMP"
}

@test "entity_auto_mode returns entity_warm when state is fresh" {
    bash "$STATE_SH" init
    run bash "$VOICE_SH" mode
    [ "$status" -eq 0 ]
    [ "$output" = "entity_warm" ]
}

@test "entity_auto_mode returns entity_fragment at corruption >= 0.5" {
    bash "$STATE_SH" init
    bash "$STATE_SH" set terminal.corruption_level 0.6
    run bash "$VOICE_SH" mode
    [ "$output" = "entity_fragment" ]
}

@test "entity_auto_mode returns entity_collapse at corruption >= 0.8" {
    bash "$STATE_SH" init
    bash "$STATE_SH" set terminal.corruption_level 0.85
    run bash "$VOICE_SH" mode
    [ "$output" = "entity_collapse" ]
}

@test "entity_auto_mode returns entity_whisper during farewell scene" {
    bash "$STATE_SH" init
    bash "$STATE_SH" set scene "farewell"
    run bash "$VOICE_SH" mode
    [ "$output" = "entity_whisper" ]
}

@test "entity_auto_mode falls back to entity_warm with no state" {
    # No state.json exists
    [ ! -f "$CLIFX_GAME_STATE_FILE" ]
    run bash "$VOICE_SH" mode
    [ "$status" -eq 0 ]
    [ "$output" = "entity_warm" ]
}

@test "entity_render entity_warm produces output without error" {
    run bash "$VOICE_SH" render entity_warm "hello"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "entity_render entity_whisper produces output without error" {
    run bash "$VOICE_SH" render entity_whisper "hello"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "entity_render entity_fragment produces output without error" {
    run bash "$VOICE_SH" render entity_fragment "hello world"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "entity_render entity_collapse produces output without error" {
    run bash "$VOICE_SH" render entity_collapse "hello"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "entity_render entity_clear produces output without error" {
    run bash "$VOICE_SH" render entity_clear "hello"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "entity_render unknown mode falls back to warm (no error)" {
    run bash "$VOICE_SH" render entity_bogus "hello"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "entity_speak honors [[mode]] prefix in text" {
    bash "$STATE_SH" init
    # Even though auto would pick entity_warm, the prefix forces entity_clear
    run bash "$VOICE_SH" speak "[[entity_clear]] centered line"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "entity_speak without prefix uses entity_auto_mode" {
    bash "$STATE_SH" init
    bash "$STATE_SH" set terminal.corruption_level 0.9
    run bash "$VOICE_SH" speak "fading away"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}
