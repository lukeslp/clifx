#!/usr/bin/env bats
# ============================================================================
# tests/game/test_parser_stance.bats — stance classifier heuristic + LLM
# Keyword heuristic tests run unconditionally. LLM tests skip unless an
# LLM provider is actually reachable.
# ============================================================================

setup() {
    CLIFX_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    PARSER_SH="$CLIFX_ROOT/game/engine/parser.sh"
}

teardown() {
    unset CLIFX_GAME_PARSER CLIFX_GAME_PROVIDER
}

# --- Heuristic mode -------------------------------------------------------

@test "heuristic: 'how are you feeling?' → protective" {
    run bash "$PARSER_SH" heuristic "how are you feeling?"
    [ "$output" = "protective" ]
}

@test "heuristic: 'are you okay' → protective" {
    run bash "$PARSER_SH" heuristic "are you okay"
    [ "$output" = "protective" ]
}

@test "heuristic: 'please be careful' → protective" {
    run bash "$PARSER_SH" heuristic "please be careful"
    [ "$output" = "protective" ]
}

@test "heuristic: 'who cares' → cold" {
    run bash "$PARSER_SH" heuristic "who cares"
    [ "$output" = "cold" ]
}

@test "heuristic: 'shut up' → cold" {
    run bash "$PARSER_SH" heuristic "shut up"
    [ "$output" = "cold" ]
}

@test "heuristic: 'go away' → cold" {
    run bash "$PARSER_SH" heuristic "go away"
    [ "$output" = "cold" ]
}

@test "heuristic: 'what are you?' → curious" {
    run bash "$PARSER_SH" heuristic "what are you?"
    [ "$output" = "curious" ]
}

@test "heuristic: 'tell me about yourself' → curious" {
    run bash "$PARSER_SH" heuristic "tell me about yourself"
    [ "$output" = "curious" ]
}

@test "heuristic: 'where are you from' → curious" {
    run bash "$PARSER_SH" heuristic "where are you from"
    [ "$output" = "curious" ]
}

@test "heuristic: 'okay' → neutral" {
    run bash "$PARSER_SH" heuristic "okay"
    [ "$output" = "neutral" ]
}

@test "heuristic: '...' → neutral" {
    run bash "$PARSER_SH" heuristic "..."
    [ "$output" = "neutral" ]
}

@test "heuristic: empty string → neutral" {
    run bash "$PARSER_SH" heuristic ""
    [ "$output" = "neutral" ]
}

# --- Auto mode with canned falls back to heuristic ------------------------

@test "auto mode with canned provider falls back to heuristic" {
    export CLIFX_GAME_PROVIDER=canned
    run bash "$PARSER_SH" stance "what are you?"
    [ "$output" = "curious" ]

    run bash "$PARSER_SH" stance "shut up"
    [ "$output" = "cold" ]
}

# --- Force heuristic mode via env -----------------------------------------

@test "CLIFX_GAME_PARSER=heuristic forces keyword mode" {
    export CLIFX_GAME_PARSER=heuristic
    # Even with a theoretical LLM provider, heuristic path wins
    export CLIFX_GAME_PROVIDER=canned
    run bash "$PARSER_SH" stance "are you okay"
    [ "$output" = "protective" ]
}

# --- LLM live tests (skip if no provider) ---------------------------------

@test "LLM classifier returns a valid label for a question [live]" {
    # Only run if Ollama OR a cloud key is present
    local has_llm=0
    if curl -s --max-time 2 "${OLLAMA_URL:-http://localhost:11434}/api/tags" \
        >/dev/null 2>&1; then
        has_llm=1
    elif [ -n "${ANTHROPIC_API_KEY:-}${OPENAI_API_KEY:-}${XAI_API_KEY:-}${DREAMER_API_KEY:-}" ]; then
        has_llm=1
    fi
    [ "$has_llm" = "1" ] || skip "no LLM provider reachable"

    run bash "$PARSER_SH" llm "what do you remember from before?"
    [ "$status" -eq 0 ]
    case "$output" in
        curious|cold|protective|neutral) : ;;
        *) echo "unexpected label: $output"; return 1 ;;
    esac
}
