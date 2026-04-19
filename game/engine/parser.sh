#!/usr/bin/env bash
# ============================================================================
# game/engine/parser.sh — player utterance classifier
# Returns one of: curious | cold | protective | neutral.
# Uses the active LLM provider for zero-shot classification when available;
# falls back to a keyword heuristic for canned/offline mode.
# ============================================================================

_PARSER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_PARSER_LLM_SH="$_PARSER_DIR/llm.sh"
_PARSER_PROVIDERS_DIR="$_PARSER_DIR/providers"

# Keyword-only classifier. Deterministic. Used when no LLM is configured, or
# as a floor when LLM output is unrecognizable.
parser_stance_heuristic() {
    local text="${1,,}"  # lowercase
    case "$text" in
        *"fuck"*|*"shut up"*|*"go away"*|*"who cares"*|*"leave me"*|*"stop it"*|*"get out"*|*"no one"*)
            echo "cold" ;;
        *"how are you"*|*"are you okay"*|*"please"*|*"careful"*|*"safe"*|*"worry"*|*"hold on"*|*"i'm here"*|*"it's okay"*)
            echo "protective" ;;
        *"who"*|*"what"*|*"why"*|*"tell me"*|*"do you"*|*"remember"*|*"where"*|*"when"*|*"how"*|\?*|*\?)
            echo "curious" ;;
        *)
            echo "neutral" ;;
    esac
}

# LLM-backed classifier. Uses the active provider via llm.sh. Falls back to
# the heuristic if the provider is canned or returns an unrecognized label.
parser_stance_llm() {
    local text="${1-}"
    local provider
    provider=$(bash "$_PARSER_LLM_SH" provider 2>/dev/null)

    if [ "$provider" = "canned" ] || [ -z "$provider" ]; then
        parser_stance_heuristic "$text"
        return 0
    fi

    local sys="You are a linguistic classifier. Given a player utterance, return exactly one lowercase word from this list: curious, cold, protective, neutral. No other text.
- curious: the player asks a question, seeks information, or expresses interest
- cold: the player is hostile, dismissive, short, or tells the entity to stop
- protective: the player expresses concern for the entity's wellbeing
- neutral: none of the above
Return only the word."

    local raw
    raw=$(bash "$_PARSER_LLM_SH" chat "$sys" "[]" "$text" 2>/dev/null) || raw=""
    # Normalize: lowercase, first word only, strip punctuation
    raw=$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' \
        | awk '{print $1}' | tr -d '[:punct:]')
    case "$raw" in
        curious|cold|protective|neutral) echo "$raw" ;;
        *) parser_stance_heuristic "$text" ;;
    esac
}

# Public entry. CLIFX_GAME_PARSER=heuristic forces keyword-only mode.
parser_stance() {
    local text="${1-}"
    case "${CLIFX_GAME_PARSER:-}" in
        heuristic) parser_stance_heuristic "$text" ;;
        llm)       parser_stance_llm "$text" ;;
        *)         parser_stance_llm "$text" ;;   # default: try LLM, fall back
    esac
}

# CLI dispatch
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    cmd="${1:-stance}"
    shift || true
    case "$cmd" in
        stance)     parser_stance "$@" ;;
        heuristic)  parser_stance_heuristic "$@" ;;
        llm)        parser_stance_llm "$@" ;;
        help|*)
            cat <<HELP
parser.sh — clifx-game player utterance classifier

Usage:
  parser.sh stance <text>       auto-pick heuristic or LLM, print stance
  parser.sh heuristic <text>    keyword-only
  parser.sh llm <text>          LLM zero-shot (falls back to heuristic)

Env:
  CLIFX_GAME_PARSER  heuristic | llm (default auto)
HELP
            ;;
    esac
fi
