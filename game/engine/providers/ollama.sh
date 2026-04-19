#!/usr/bin/env bash
# ============================================================================
# game/engine/providers/ollama.sh — Ollama local + Ollama Cloud provider
# Streams tokens from POST /api/chat to stdout as they arrive.
#
# Env:
#   OLLAMA_URL          default http://localhost:11434
#   CLIFX_GAME_MODEL    default qwen2.5:7b
#   OLLAMA_API_KEY      optional; sent as "Authorization: Bearer <key>"
#   CLIFX_GAME_TIMEOUT  request timeout seconds, default 120
# ============================================================================

_OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
_OLLAMA_MODEL="${CLIFX_GAME_MODEL:-qwen2.5:7b}"
_OLLAMA_TIMEOUT="${CLIFX_GAME_TIMEOUT:-120}"

_ollama_require() {
    command -v curl >/dev/null 2>&1 || { echo "ollama.sh: curl required" >&2; return 1; }
    command -v jq >/dev/null 2>&1 || { echo "ollama.sh: jq required" >&2; return 1; }
}

# Is the Ollama server reachable at all?
ollama_health() {
    curl -s --max-time 3 "${_OLLAMA_URL}/api/tags" >/dev/null 2>&1
}

# Build the messages array: prepend system prompt (if any), append transcript,
# append final user message. Transcript must already be a JSON array of
# {role, content} objects — caller translates from our own {who, line} form.
_ollama_build_messages() {
    local system_prompt="$1"
    local transcript="$2"
    local user_message="$3"

    # Default transcript to empty array if empty/blank
    [ -z "$transcript" ] && transcript="[]"

    jq -n \
        --arg sys "$system_prompt" \
        --argjson prior "$transcript" \
        --arg user "$user_message" \
        '
        (if $sys == "" then [] else [{role: "system", content: $sys}] end)
        + $prior
        + (if $user == "" then [] else [{role: "user", content: $user}] end)
        '
}

# Stream a chat completion. Emits raw entity text to stdout, one token chunk
# at a time as NDJSON lines arrive.
provider_chat() {
    local system_prompt="${1:-}"
    local transcript="${2:-[]}"
    local user_message="${3:-}"

    _ollama_require || return 1

    if ! ollama_health; then
        echo "ollama.sh: $_OLLAMA_URL unreachable" >&2
        return 2
    fi

    local messages; messages=$(_ollama_build_messages \
        "$system_prompt" "$transcript" "$user_message")
    local body; body=$(jq -n \
        --arg model "$_OLLAMA_MODEL" \
        --argjson msgs "$messages" \
        '{model: $model, messages: $msgs, stream: true}')

    local auth_hdr=()
    if [ -n "${OLLAMA_API_KEY:-}" ]; then
        auth_hdr=(-H "Authorization: Bearer ${OLLAMA_API_KEY}")
    fi

    # -N disables curl's output buffering so tokens stream immediately.
    # Read each NDJSON line, extract .message.content, emit without newline.
    curl -sN --max-time "$_OLLAMA_TIMEOUT" \
        -X POST "${_OLLAMA_URL}/api/chat" \
        -H "Content-Type: application/json" \
        "${auth_hdr[@]}" \
        -d "$body" \
        | while IFS= read -r line; do
            [ -z "$line" ] && continue
            # Extract token content; jq returns empty string for missing keys
            # with 'empty', keeping stdout clean.
            local token
            token=$(printf '%s' "$line" | jq -r '.message.content // empty' 2>/dev/null || true)
            if [ -n "$token" ]; then
                printf '%s' "$token"
            fi
            # Detect error shape from Ollama
            local err
            err=$(printf '%s' "$line" | jq -r '.error // empty' 2>/dev/null || true)
            if [ -n "$err" ]; then
                echo "" >&2
                echo "ollama.sh: $err" >&2
                return 3
            fi
        done
    # Trailing newline so downstream consumers see a line-complete message
    printf '\n'
}

# One-shot non-streaming variant (used by parser.sh stance classifier to get
# a single token/word back without the streaming machinery).
ollama_oneshot() {
    local system_prompt="${1:-}"
    local user_message="${2:-}"

    _ollama_require || return 1
    ollama_health || { echo "ollama.sh: unreachable" >&2; return 2; }

    local messages; messages=$(_ollama_build_messages \
        "$system_prompt" "[]" "$user_message")
    local body; body=$(jq -n \
        --arg model "$_OLLAMA_MODEL" \
        --argjson msgs "$messages" \
        '{model: $model, messages: $msgs, stream: false}')

    local auth_hdr=()
    [ -n "${OLLAMA_API_KEY:-}" ] && auth_hdr=(-H "Authorization: Bearer ${OLLAMA_API_KEY}")

    curl -s --max-time "$_OLLAMA_TIMEOUT" \
        -X POST "${_OLLAMA_URL}/api/chat" \
        -H "Content-Type: application/json" \
        "${auth_hdr[@]}" \
        -d "$body" \
        | jq -r '.message.content // .error // empty'
}

# List available models (used by auto-detect to report what's ready)
ollama_models() {
    _ollama_require || return 1
    ollama_health || return 2
    curl -s --max-time 5 "${_OLLAMA_URL}/api/tags" | jq -r '.models[]?.name // empty'
}
