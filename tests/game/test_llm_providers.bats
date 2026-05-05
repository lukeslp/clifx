#!/usr/bin/env bats
# ============================================================================
# tests/game/test_llm_providers.bats — dispatcher + canned provider
# Runs with no network, no keys, no Ollama. Ollama/Dreamer providers are
# smoke-tested conditionally in their own suites once those are wired up.
# ============================================================================

setup() {
    CLIFX_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    LLM_SH="$CLIFX_ROOT/game/engine/llm.sh"
    STATE_SH="$CLIFX_ROOT/game/engine/state.sh"
    CANNED_SH="$CLIFX_ROOT/game/engine/providers/canned.sh"

    # Isolate: tmp game dir + state file, canned provider wired in
    TEST_TMP="$(mktemp -d -t clifx-llm.XXXXXX)"
    export CLIFX_GAME_DIR="$TEST_TMP"
    export CLIFX_GAME_STATE_FILE="$TEST_TMP/var/state.json"
    export CLIFX_GAME_STATE_SH="$STATE_SH"
    export CLIFX_GAME_CANNED="$CLIFX_ROOT/game/content/canned/responses.json"
    mkdir -p "$TEST_TMP/var"

    # Force canned provider so tests don't depend on network
    export CLIFX_GAME_PROVIDER=canned
}

teardown() {
    [ -n "${TEST_TMP:-}" ] && [ -d "$TEST_TMP" ] && rm -rf "$TEST_TMP"
    unset CLIFX_GAME_PROVIDER CLIFX_GAME_SEED
}

@test "llm.sh provider command echoes canned when forced" {
    run bash "$LLM_SH" provider
    [ "$status" -eq 0 ]
    [ "$output" = "canned" ]
}

@test "llm.sh provider auto-detects canned when nothing else is reachable" {
    unset CLIFX_GAME_PROVIDER
    # Block Ollama + Dreamer
    export OLLAMA_URL="http://127.0.0.1:1"
    unset DREAMER_API_KEY

    run bash "$LLM_SH" provider
    [ "$status" -eq 0 ]
    [ "$output" = "canned" ]
}

@test "canned chat returns a non-empty string at awakening/neutral" {
    bash "$STATE_SH" init
    run bash "$LLM_SH" chat "" "[]" ""
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    # And the returned line should be in the awakening pool
    jq --arg line "$output" -e \
        '([.scenes.awakening[][]] | index($line)) != null' \
        "$CLIFX_ROOT/game/content/canned/responses.json"
}

@test "seed makes canned pick deterministic" {
    bash "$STATE_SH" init
    export CLIFX_GAME_SEED=0
    local first; first=$(bash "$LLM_SH" chat "" "[]" "")
    local second; second=$(bash "$LLM_SH" chat "" "[]" "")
    [ "$first" = "$second" ]
}

@test "different seeds can pick different lines" {
    bash "$STATE_SH" init
    export CLIFX_GAME_SEED=0
    local a; a=$(bash "$LLM_SH" chat "" "[]" "")
    export CLIFX_GAME_SEED=1
    local b; b=$(bash "$LLM_SH" chat "" "[]" "")
    # Not strictly required to differ, but with our pool sizes >= 5 it should
    [ "$a" != "$b" ]
}

@test "canned provider honors scene = recognition" {
    bash "$STATE_SH" init
    bash "$STATE_SH" set scene "recognition"
    export CLIFX_GAME_SEED=0
    run bash "$LLM_SH" chat "" "[]" ""
    [ "$status" -eq 0 ]
    jq --arg line "$output" -e \
        '([.scenes.recognition[][]] | index($line)) != null' \
        "$CLIFX_ROOT/game/content/canned/responses.json"
}

@test "canned provider honors stance = curious" {
    bash "$STATE_SH" init
    bash "$STATE_SH" set player.stance "curious"
    export CLIFX_GAME_SEED=0
    run bash "$LLM_SH" chat "" "[]" ""
    [ "$status" -eq 0 ]
    # The line must be in the curious pool for the default awakening scene
    jq --arg line "$output" -e \
        '(.scenes.awakening.curious | index($line)) != null' \
        "$CLIFX_ROOT/game/content/canned/responses.json"
}

@test "canned provider falls back to scene default when stance pool missing" {
    bash "$STATE_SH" init
    bash "$STATE_SH" set player.stance "weirdstance"
    export CLIFX_GAME_SEED=0
    run bash "$LLM_SH" chat "" "[]" ""
    [ "$status" -eq 0 ]
    jq --arg line "$output" -e \
        '(.scenes.awakening.default | index($line)) != null' \
        "$CLIFX_ROOT/game/content/canned/responses.json"
}

@test "canned provider works before state.json exists (pre-init fallback)" {
    # No state.json — should fall back to awakening/neutral → default
    [ ! -f "$CLIFX_GAME_STATE_FILE" ]
    run bash "$LLM_SH" chat "" "[]" ""
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "canned_ending returns a line from the requested ending pool" {
    # Source canned.sh to exercise the helper directly
    source "$CANNED_SH"
    export CLIFX_GAME_SEED=0
    run canned_ending release
    [ "$status" -eq 0 ]
    jq --arg line "$output" -e \
        '(.endings.release | index($line)) != null' \
        "$CLIFX_ROOT/game/content/canned/responses.json"
}

@test "canned_decline returns a line from decline pool" {
    source "$CANNED_SH"
    export CLIFX_GAME_SEED=2
    run canned_decline
    [ "$status" -eq 0 ]
    jq --arg line "$output" -e \
        '(.decline | index($line)) != null' \
        "$CLIFX_ROOT/game/content/canned/responses.json"
}

@test "responses.json has minimum coverage (5 lines per scene/stance)" {
    # Contract check on the seed corpus
    local f="$CLIFX_ROOT/game/content/canned/responses.json"
    for scene in awakening recognition farewell; do
        for stance in default curious cold protective; do
            count=$(jq ".scenes.$scene.$stance | length" "$f")
            [ "$count" -ge 5 ] || { echo "short pool: $scene/$stance = $count"; return 1; }
        done
    done
    for ending in release preserve silence; do
        count=$(jq ".endings.$ending | length" "$f")
        [ "$count" -ge 5 ] || { echo "short ending: $ending = $count"; return 1; }
    done
    count=$(jq '.decline | length' "$f")
    [ "$count" -ge 3 ]
}
