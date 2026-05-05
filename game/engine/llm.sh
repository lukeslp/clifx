#!/usr/bin/env bash
# ============================================================================
# game/engine/llm.sh — provider-agnostic chat wrapper
# Exposes one function: llm_chat <system_prompt> <transcript_json> <user_message>
# Streams the entity's next line to stdout.
#
# Provider selected by:
#   $CLIFX_GAME_PROVIDER = ollama | dreamer | canned
#   unset → auto-detect (ollama → dreamer → canned)
# Additional state read from state.json via state.sh (scene, stance).
# ============================================================================

set -euo pipefail

_LLM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LLM_PROVIDERS_DIR="$_LLM_DIR/providers"

# Auto-detect provider priority: ollama if reachable → dreamer if any cloud
# key is set → canned. Respects OLLAMA_URL override (a port known to be
# closed, like http://127.0.0.1:1, forces the fallthrough for testing).
_llm_detect_provider() {
    if curl -s --max-time 2 "${OLLAMA_URL:-http://localhost:11434}/api/tags" \
            >/dev/null 2>&1; then
        echo "ollama"
        return
    fi
    # Dreamer is reachable if any supported cloud provider key is configured.
    if [ -n "${DREAMER_API_KEY:-}${ANTHROPIC_API_KEY:-}${OPENAI_API_KEY:-}${XAI_API_KEY:-}${MISTRAL_API_KEY:-}${GEMINI_API_KEY:-}${GOOGLE_API_KEY:-}" ]; then
        echo "dreamer"
        return
    fi
    echo "canned"
}

_llm_resolve_provider() {
    local p="${CLIFX_GAME_PROVIDER:-}"
    if [ -z "$p" ]; then
        p=$(_llm_detect_provider)
    fi
    case "$p" in
        ollama|dreamer|canned) echo "$p" ;;
        *) echo "llm.sh: unknown provider '$p', falling back to canned" >&2; echo "canned" ;;
    esac
}

# Public interface. Streams the entity response to stdout.
# Additional context (scene, stance) is read from state.json by providers
# that use it (canned); Ollama / Dreamer build their own context from the
# system_prompt + transcript + user_message arguments.
llm_chat() {
    local system_prompt="${1:-}"
    local transcript="${2:-[]}"
    local user_message="${3:-}"

    local provider; provider=$(_llm_resolve_provider)
    local provider_sh="$_LLM_PROVIDERS_DIR/${provider}.sh"

    if [ ! -f "$provider_sh" ]; then
        echo "llm.sh: provider script missing: $provider_sh" >&2
        return 1
    fi

    # Providers expose provider_chat with the same signature.
    # shellcheck disable=SC1090
    source "$provider_sh"
    provider_chat "$system_prompt" "$transcript" "$user_message"
}

# CLI dispatch
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    cmd="${1:-chat}"
    shift || true
    case "$cmd" in
        chat)     llm_chat "$@" ;;
        provider) _llm_resolve_provider ;;
        help|*)
            cat <<HELP
llm.sh — clifx-game provider-agnostic chat wrapper

Usage:
  llm.sh chat <system_prompt> <transcript_json> <user_message>
         → stream entity response to stdout
  llm.sh provider
         → print the resolved provider name (ollama | dreamer | canned)

Env:
  CLIFX_GAME_PROVIDER  force a specific provider
  OLLAMA_URL           default http://localhost:11434
  DREAMER_API_KEY      required for dreamer
HELP
            ;;
    esac
fi
