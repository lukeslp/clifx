#!/usr/bin/env bats
# ============================================================================
# tests/game/test_state.bats — game/engine/state.sh roundtrip + semantics
# ============================================================================

setup() {
    CLIFX_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    STATE_SH="$CLIFX_ROOT/game/engine/state.sh"

    # Isolate each test: fresh tmp dir as CLIFX_GAME_DIR
    TEST_TMP="$(mktemp -d -t clifx-state.XXXXXX)"
    export CLIFX_GAME_DIR="$TEST_TMP"
    export CLIFX_GAME_STATE_FILE="$TEST_TMP/var/state.json"
    mkdir -p "$TEST_TMP/var"
}

teardown() {
    [ -n "${TEST_TMP:-}" ] && [ -d "$TEST_TMP" ] && rm -rf "$TEST_TMP"
}

@test "state init creates a state file with default schema" {
    run bash "$STATE_SH" init
    [ "$status" -eq 0 ]
    [ -f "$CLIFX_GAME_STATE_FILE" ]

    run bash "$STATE_SH" get scene
    [ "$status" -eq 0 ]
    [ "$output" = "awakening" ]

    run bash "$STATE_SH" get entity.phase
    [ "$output" = "1" ]

    run bash "$STATE_SH" get player.message_count
    [ "$output" = "0" ]
}

@test "state set writes a string value and get reads it back" {
    bash "$STATE_SH" init
    run bash "$STATE_SH" set player.stance "curious"
    [ "$status" -eq 0 ]

    run bash "$STATE_SH" get player.stance
    [ "$output" = "curious" ]
}

@test "state set accepts a JSON number and round-trips as number" {
    bash "$STATE_SH" init
    bash "$STATE_SH" set terminal.corruption_level 0.42

    run bash "$STATE_SH" get terminal.corruption_level
    [ "$output" = "0.42" ]
}

@test "state set accepts JSON null" {
    bash "$STATE_SH" init
    bash "$STATE_SH" set enrichment.identity '"Luke (luke@example.com)"'
    run bash "$STATE_SH" get enrichment.identity
    [ "$output" = "Luke (luke@example.com)" ]

    bash "$STATE_SH" set enrichment.identity null
    run bash "$STATE_SH" get enrichment.identity
    [ "$output" = "null" ]
}

@test "state inc increments a numeric key" {
    bash "$STATE_SH" init
    bash "$STATE_SH" inc player.message_count
    bash "$STATE_SH" inc player.message_count
    bash "$STATE_SH" inc player.message_count 3

    run bash "$STATE_SH" get player.message_count
    [ "$output" = "5" ]
}

@test "state inc creates missing numeric keys at zero before adding" {
    bash "$STATE_SH" init
    bash "$STATE_SH" inc entity.custom_counter 7

    run bash "$STATE_SH" get entity.custom_counter
    [ "$output" = "7" ]
}

@test "state log appends to transcript preserving order" {
    bash "$STATE_SH" init
    bash "$STATE_SH" log entity "hello?"
    bash "$STATE_SH" log player "who are you"
    bash "$STATE_SH" log entity "i don't know yet"

    run bash "$STATE_SH" get 'transcript | length'
    [ "$output" = "3" ]

    run bash "$STATE_SH" get 'transcript[0].who'
    [ "$output" = "entity" ]
    run bash "$STATE_SH" get 'transcript[0].line'
    [ "$output" = "hello?" ]

    run bash "$STATE_SH" get 'transcript[2].line'
    [ "$output" = "i don't know yet" ]
}

@test "state log accepts JSON meta and preserves it" {
    bash "$STATE_SH" init
    bash "$STATE_SH" log entity "first line" '{"voice":"whisper","corruption":0.1}'

    run bash "$STATE_SH" get 'transcript[0].meta.voice'
    [ "$output" = "whisper" ]
    run bash "$STATE_SH" get 'transcript[0].meta.corruption'
    [ "$output" = "0.1" ]
}

@test "state dump prints full JSON" {
    bash "$STATE_SH" init
    bash "$STATE_SH" inc player.message_count

    run bash "$STATE_SH" dump
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.player.message_count == 1' >/dev/null
}

@test "state reset removes the state file" {
    bash "$STATE_SH" init
    [ -f "$CLIFX_GAME_STATE_FILE" ]

    run bash "$STATE_SH" reset
    [ "$status" -eq 0 ]
    [ ! -f "$CLIFX_GAME_STATE_FILE" ]
}

@test "state get on missing file errors cleanly" {
    run bash "$STATE_SH" get scene
    [ "$status" -ne 0 ]
}

@test "last_interaction updates on writes" {
    bash "$STATE_SH" init
    local before; before=$(bash "$STATE_SH" get last_interaction)
    sleep 1
    bash "$STATE_SH" inc player.message_count
    local after; after=$(bash "$STATE_SH" get last_interaction)
    [ "$before" != "$after" ]
}
