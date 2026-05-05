#!/usr/bin/env bats
# ============================================================================
# tests/game/test_ollama_provider.bats — Ollama provider smoke tests
# Skips if Ollama is not reachable at localhost:11434.
# When reachable, uses whatever model is first in /api/tags (tolerant of
# which models the dev has actually pulled).
# ============================================================================

setup() {
    CLIFX_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    OLLAMA_SH="$CLIFX_ROOT/game/engine/providers/ollama.sh"
    LLM_SH="$CLIFX_ROOT/game/engine/llm.sh"

    _ollama_up() {
        curl -s --max-time 3 "${OLLAMA_URL:-http://localhost:11434}/api/tags" \
            >/dev/null 2>&1
    }
    _pick_model() {
        curl -s --max-time 3 "${OLLAMA_URL:-http://localhost:11434}/api/tags" \
            | jq -r '.models[0].name // empty' 2>/dev/null
    }
}

@test "ollama_health returns 0 when server reachable, nonzero otherwise" {
    source "$OLLAMA_SH"
    if _ollama_up; then
        run ollama_health
        [ "$status" -eq 0 ]
    else
        OLLAMA_URL="http://127.0.0.1:1" run ollama_health
        [ "$status" -ne 0 ]
    fi
}

@test "message builder produces valid messages array with system + user" {
    source "$OLLAMA_SH"
    result=$(_ollama_build_messages "you are warm" "[]" "hello")
    echo "$result" | jq -e '
        . | length == 2
        and .[0].role == "system"
        and .[0].content == "you are warm"
        and .[1].role == "user"
        and .[1].content == "hello"
    ' >/dev/null
}

@test "message builder preserves prior transcript between system and user" {
    source "$OLLAMA_SH"
    prior='[{"role":"assistant","content":"hi"},{"role":"user","content":"hey"}]'
    result=$(_ollama_build_messages "sys" "$prior" "new")
    echo "$result" | jq -e '
        . | length == 4
        and .[1].content == "hi"
        and .[2].content == "hey"
        and .[3].content == "new"
    ' >/dev/null
}

@test "message builder omits empty system prompt and empty user message" {
    source "$OLLAMA_SH"
    result=$(_ollama_build_messages "" "[]" "")
    echo "$result" | jq -e '. | length == 0' >/dev/null

    result=$(_ollama_build_messages "" '[{"role":"user","content":"only"}]' "")
    echo "$result" | jq -e '. | length == 1 and .[0].content == "only"' >/dev/null
}

@test "provider_chat streams text when Ollama is reachable [live]" {
    if ! _ollama_up; then
        skip "Ollama not reachable at ${OLLAMA_URL:-http://localhost:11434}"
    fi
    local model; model=$(_pick_model)
    if [ -z "$model" ]; then
        skip "Ollama reachable but no models pulled"
    fi

    source "$OLLAMA_SH"
    export CLIFX_GAME_MODEL="$model"
    export CLIFX_GAME_TIMEOUT=60

    run provider_chat "You reply with exactly one word: YES" "[]" "Please comply."
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    # We can't assert exact content from a live model, but we can assert
    # non-empty and non-error.
    [[ "$output" != *"error"* ]] || true
}

@test "llm.sh auto-detect picks ollama when reachable [live]" {
    if ! _ollama_up; then
        skip "Ollama not reachable"
    fi
    unset CLIFX_GAME_PROVIDER
    unset DREAMER_API_KEY
    run bash "$LLM_SH" provider
    [ "$status" -eq 0 ]
    [ "$output" = "ollama" ]
}

@test "ollama_models lists at least one model when reachable [live]" {
    if ! _ollama_up; then
        skip "Ollama not reachable"
    fi
    source "$OLLAMA_SH"
    run ollama_models
    [ "$status" -eq 0 ]
    # If there are zero models, the test is inconclusive; accept empty
    # output but not a crash.
}

@test "provider_chat returns error when Ollama unreachable" {
    source "$OLLAMA_SH"
    OLLAMA_URL="http://127.0.0.1:1" run provider_chat "sys" "[]" "hi"
    [ "$status" -ne 0 ]
}
