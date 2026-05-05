#!/usr/bin/env bash
# ============================================================================
# game/engine/providers/dreamer.sh — cloud LLM via direct provider APIs
#
# "Dreamer" here mirrors Luke's env-keyed multi-provider routing (from
# ux-glm-chat) without introducing a gateway. v0.1 supports Anthropic
# (SSE streaming) and OpenAI-compatible endpoints (xAI, OpenAI, Mistral,
# Gemini /v1beta2/openai, etc.).
#
# Env:
#   DREAMER_PROVIDER  anthropic | openai | xai | mistral | gemini
#                     (default anthropic; openai-compat for the rest)
#   DREAMER_API_KEY   unified alias, falls back to <PROVIDER>_API_KEY
#   CLIFX_GAME_MODEL  model name; per-provider default if unset
#   CLIFX_GAME_TIMEOUT  seconds, default 120
# ============================================================================

_DREAMER_PROVIDER="${DREAMER_PROVIDER:-anthropic}"
_DREAMER_TIMEOUT="${CLIFX_GAME_TIMEOUT:-120}"

_dreamer_require() {
    command -v curl >/dev/null 2>&1 || { echo "dreamer.sh: curl required" >&2; return 1; }
    command -v jq >/dev/null 2>&1 || { echo "dreamer.sh: jq required" >&2; return 1; }
}

_dreamer_provider_url() {
    case "$1" in
        anthropic) echo "https://api.anthropic.com/v1/messages" ;;
        openai)    echo "https://api.openai.com/v1/chat/completions" ;;
        xai)       echo "https://api.x.ai/v1/chat/completions" ;;
        mistral)   echo "https://api.mistral.ai/v1/chat/completions" ;;
        gemini)    echo "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions" ;;
        *)         return 1 ;;
    esac
}

_dreamer_default_model() {
    case "$1" in
        anthropic) echo "claude-sonnet-4-6" ;;
        openai)    echo "gpt-5-mini" ;;
        xai)       echo "grok-4-0709" ;;
        mistral)   echo "mistral-large-latest" ;;
        gemini)    echo "gemini-3.1-flash-lite-preview" ;;
        *)         echo "" ;;
    esac
}

_dreamer_resolve_key() {
    local provider="$1"
    local key="${DREAMER_API_KEY:-}"
    if [ -z "$key" ]; then
        case "$provider" in
            anthropic) key="${ANTHROPIC_API_KEY:-}" ;;
            openai)    key="${OPENAI_API_KEY:-}" ;;
            xai)       key="${XAI_API_KEY:-}" ;;
            mistral)   key="${MISTRAL_API_KEY:-}" ;;
            gemini)    key="${GEMINI_API_KEY:-GOOGLE_API_KEY}" ; [ "$key" = "GOOGLE_API_KEY" ] && key="${GOOGLE_API_KEY:-}" ;;
        esac
    fi
    printf '%s' "$key"
}

# Build an OpenAI-compatible messages array: system + prior transcript + user.
_dreamer_openai_messages() {
    local system_prompt="$1"
    local transcript="$2"
    local user_message="$3"
    [ -z "$transcript" ] && transcript="[]"
    jq -n \
        --arg sys "$system_prompt" \
        --argjson prior "$transcript" \
        --arg user "$user_message" \
        '
        (if $sys == "" then [] else [{role:"system", content:$sys}] end)
        + $prior
        + (if $user == "" then [] else [{role:"user", content:$user}] end)
        '
}

# Anthropic uses a split: top-level "system" + messages of user/assistant only.
# Transcript may contain system entries from other providers; we strip them.
_dreamer_anthropic_messages() {
    local transcript="$1"
    local user_message="$2"
    [ -z "$transcript" ] && transcript="[]"
    jq -n \
        --argjson prior "$transcript" \
        --arg user "$user_message" \
        '
        ($prior | map(select(.role == "user" or .role == "assistant")))
        + (if $user == "" then [] else [{role:"user", content:$user}] end)
        '
}

# --- Anthropic SSE streaming ---
_dreamer_chat_anthropic() {
    local system_prompt="$1"
    local transcript="$2"
    local user_message="$3"
    local key model url body
    key=$(_dreamer_resolve_key anthropic)
    [ -z "$key" ] && { echo "dreamer.sh: no anthropic api key" >&2; return 1; }

    model="${CLIFX_GAME_MODEL:-$(_dreamer_default_model anthropic)}"
    url="https://api.anthropic.com/v1/messages"

    local messages; messages=$(_dreamer_anthropic_messages "$transcript" "$user_message")
    body=$(jq -n \
        --arg model "$model" \
        --arg sys "$system_prompt" \
        --argjson msgs "$messages" \
        --argjson max_tokens 1024 \
        '{
            model: $model,
            max_tokens: $max_tokens,
            stream: true,
            system: (if $sys == "" then "" else $sys end),
            messages: $msgs
        }')

    curl -sN --max-time "$_DREAMER_TIMEOUT" -X POST "$url" \
        -H "x-api-key: $key" \
        -H "anthropic-version: 2023-06-01" \
        -H "content-type: application/json" \
        -d "$body" \
        | while IFS= read -r line; do
            # Anthropic SSE: "data: {...}" lines, with an event: line preceding
            case "$line" in
                data:*)
                    local payload="${line#data: }"
                    [ "$payload" = "[DONE]" ] && continue
                    # Pull text from content_block_delta events; ignore others
                    local token
                    token=$(printf '%s' "$payload" \
                        | jq -r 'select(.type == "content_block_delta") | .delta.text // empty' \
                        2>/dev/null || true)
                    [ -n "$token" ] && printf '%s' "$token"
                    # Surface errors
                    local err
                    err=$(printf '%s' "$payload" \
                        | jq -r '.error.message // empty' 2>/dev/null || true)
                    if [ -n "$err" ]; then
                        echo "" >&2
                        echo "dreamer.sh/anthropic: $err" >&2
                        return 3
                    fi
                    ;;
            esac
        done
    printf '\n'
}

# --- OpenAI-compatible SSE streaming (xai, openai, mistral, gemini) ---
_dreamer_chat_openai_compat() {
    local provider="$1"
    local system_prompt="$2"
    local transcript="$3"
    local user_message="$4"

    local key model url body
    key=$(_dreamer_resolve_key "$provider")
    [ -z "$key" ] && { echo "dreamer.sh: no $provider api key" >&2; return 1; }

    model="${CLIFX_GAME_MODEL:-$(_dreamer_default_model "$provider")}"
    url=$(_dreamer_provider_url "$provider")

    local messages; messages=$(_dreamer_openai_messages \
        "$system_prompt" "$transcript" "$user_message")
    body=$(jq -n \
        --arg model "$model" \
        --argjson msgs "$messages" \
        '{model: $model, messages: $msgs, stream: true}')

    curl -sN --max-time "$_DREAMER_TIMEOUT" -X POST "$url" \
        -H "Authorization: Bearer $key" \
        -H "Content-Type: application/json" \
        -d "$body" \
        | while IFS= read -r line; do
            case "$line" in
                data:*)
                    local payload="${line#data: }"
                    [ "$payload" = "[DONE]" ] && continue
                    local token
                    token=$(printf '%s' "$payload" \
                        | jq -r '.choices[0].delta.content // empty' \
                        2>/dev/null || true)
                    [ -n "$token" ] && printf '%s' "$token"
                    local err
                    err=$(printf '%s' "$payload" \
                        | jq -r '.error.message // empty' 2>/dev/null || true)
                    if [ -n "$err" ]; then
                        echo "" >&2
                        echo "dreamer.sh/$provider: $err" >&2
                        return 3
                    fi
                    ;;
            esac
        done
    printf '\n'
}

# Public provider interface.
provider_chat() {
    local system_prompt="${1:-}"
    local transcript="${2:-[]}"
    local user_message="${3:-}"

    _dreamer_require || return 1

    case "$_DREAMER_PROVIDER" in
        anthropic)
            _dreamer_chat_anthropic "$system_prompt" "$transcript" "$user_message"
            ;;
        openai|xai|mistral|gemini)
            _dreamer_chat_openai_compat "$_DREAMER_PROVIDER" \
                "$system_prompt" "$transcript" "$user_message"
            ;;
        *)
            echo "dreamer.sh: unknown provider '$_DREAMER_PROVIDER'" >&2
            return 1
            ;;
    esac
}

# Check whether a key is configured for the current provider (used by
# llm.sh auto-detection).
dreamer_has_key() {
    local k; k=$(_dreamer_resolve_key "$_DREAMER_PROVIDER")
    [ -n "$k" ]
}
