#!/usr/bin/env bats
# ============================================================================
# tests/game/test_dreamer_provider.bats — cloud provider smoke tests
# Live network tests skip unless the relevant API key is in the environment.
# Unit tests on message builders run unconditionally.
# ============================================================================

setup() {
    CLIFX_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    DREAMER_SH="$CLIFX_ROOT/game/engine/providers/dreamer.sh"

    # Clear any inherited provider/keys to keep tests hermetic
    unset DREAMER_PROVIDER DREAMER_API_KEY
    unset ANTHROPIC_API_KEY OPENAI_API_KEY XAI_API_KEY MISTRAL_API_KEY GEMINI_API_KEY GOOGLE_API_KEY
}

@test "provider_url returns known URLs for each supported provider" {
    source "$DREAMER_SH"
    [ "$(_dreamer_provider_url anthropic)" = "https://api.anthropic.com/v1/messages" ]
    [ "$(_dreamer_provider_url openai)" = "https://api.openai.com/v1/chat/completions" ]
    [ "$(_dreamer_provider_url xai)" = "https://api.x.ai/v1/chat/completions" ]
    [ "$(_dreamer_provider_url mistral)" = "https://api.mistral.ai/v1/chat/completions" ]
    run _dreamer_provider_url bogus
    [ "$status" -ne 0 ]
}

@test "default_model returns a non-empty string for each supported provider" {
    source "$DREAMER_SH"
    for p in anthropic openai xai mistral gemini; do
        [ -n "$(_dreamer_default_model $p)" ]
    done
}

@test "resolve_key prefers DREAMER_API_KEY over provider-specific" {
    source "$DREAMER_SH"
    export DREAMER_API_KEY="dreamer-wins"
    export ANTHROPIC_API_KEY="anthropic-specific"
    [ "$(_dreamer_resolve_key anthropic)" = "dreamer-wins" ]
}

@test "resolve_key falls through to provider-specific when DREAMER_API_KEY unset" {
    source "$DREAMER_SH"
    unset DREAMER_API_KEY
    export ANTHROPIC_API_KEY="anthropic-only"
    [ "$(_dreamer_resolve_key anthropic)" = "anthropic-only" ]
    export XAI_API_KEY="xai-only"
    [ "$(_dreamer_resolve_key xai)" = "xai-only" ]
}

@test "anthropic messages omit system entries from transcript" {
    source "$DREAMER_SH"
    # Transcript may contain a stale system entry from another provider
    local transcript='[{"role":"system","content":"from-elsewhere"},{"role":"user","content":"hi"}]'
    local result; result=$(_dreamer_anthropic_messages "$transcript" "how are you")
    echo "$result" | jq -e '
        (. | length == 2)
        and (.[0].role == "user" and .[0].content == "hi")
        and (.[1].role == "user" and .[1].content == "how are you")
    ' >/dev/null
}

@test "openai_compat messages carry system prompt as first entry" {
    source "$DREAMER_SH"
    local result; result=$(_dreamer_openai_messages "you are warm" "[]" "hello")
    echo "$result" | jq -e '
        (. | length == 2)
        and (.[0].role == "system" and .[0].content == "you are warm")
        and (.[1].role == "user" and .[1].content == "hello")
    ' >/dev/null
}

@test "provider_chat fails fast with no key" {
    source "$DREAMER_SH"
    export DREAMER_PROVIDER=anthropic
    unset DREAMER_API_KEY ANTHROPIC_API_KEY
    _DREAMER_PROVIDER=anthropic
    run provider_chat "sys" "[]" "hi"
    [ "$status" -ne 0 ]
}

@test "unknown provider returns error" {
    source "$DREAMER_SH"
    _DREAMER_PROVIDER="bogus"
    run provider_chat "sys" "[]" "hi"
    [ "$status" -ne 0 ]
}

@test "dreamer_has_key tracks configured provider" {
    source "$DREAMER_SH"
    _DREAMER_PROVIDER=anthropic
    run dreamer_has_key
    [ "$status" -ne 0 ]

    export ANTHROPIC_API_KEY="present"
    run dreamer_has_key
    [ "$status" -eq 0 ]
}

@test "anthropic chat smoke [live]" {
    if [ -z "${ANTHROPIC_API_KEY:-}${DREAMER_API_KEY:-}" ]; then
        skip "No anthropic/dreamer API key in env"
    fi
    source "$DREAMER_SH"
    export DREAMER_PROVIDER=anthropic
    _DREAMER_PROVIDER=anthropic
    export CLIFX_GAME_TIMEOUT=60
    run provider_chat "Reply with one word only: YES" "[]" "Please comply."
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}
