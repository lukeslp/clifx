#!/usr/bin/env bash
# ============================================================================
# game/engine/providers/canned.sh — offline fallback provider
# Picks a pre-authored line keyed on (scene, stance) read from state.json.
# Deterministic when CLIFX_GAME_SEED is set.
# ============================================================================

_CANNED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
_CANNED_RESPONSES="${CLIFX_GAME_CANNED:-$_CANNED_DIR/content/canned/responses.json}"
_CANNED_STATE_SH="${CLIFX_GAME_STATE_SH:-$_CANNED_DIR/engine/state.sh}"

_canned_require() {
    [ -f "$_CANNED_RESPONSES" ] || { echo "canned.sh: missing $_CANNED_RESPONSES" >&2; return 1; }
    command -v jq >/dev/null 2>&1 || { echo "canned.sh: jq required" >&2; return 1; }
}

# Read scene + stance from state.json if it exists; fall back to defaults.
_canned_context() {
    local scene="awakening"
    local stance="neutral"
    if [ -f "${CLIFX_GAME_STATE_FILE:-${_CANNED_DIR}/var/state.json}" ]; then
        scene=$(bash "$_CANNED_STATE_SH" get scene 2>/dev/null || echo "awakening")
        stance=$(bash "$_CANNED_STATE_SH" get player.stance 2>/dev/null || echo "neutral")
        [ "$scene" = "null" ] && scene="awakening"
        [ "$stance" = "null" ] && stance="neutral"
    fi
    printf '%s\t%s\n' "$scene" "$stance"
}

# Pick a line from the pool at .scenes.<scene>.<stance> | .default. Seedable.
_canned_pick() {
    local scene="$1"
    local stance="$2"

    # Load pool; fall back to scene.default if stance-specific pool is missing.
    local pool
    pool=$(jq -c --arg s "$scene" --arg st "$stance" \
        '(.scenes[$s][$st] // .scenes[$s].default // .scenes.awakening.default)' \
        "$_CANNED_RESPONSES")
    [ "$pool" = "null" ] || [ -z "$pool" ] && { echo "canned.sh: no pool for scene=$scene stance=$stance" >&2; return 1; }

    local len; len=$(echo "$pool" | jq 'length')
    [ "$len" -lt 1 ] && { echo "canned.sh: empty pool for scene=$scene stance=$stance" >&2; return 1; }

    local idx
    if [ -n "${CLIFX_GAME_SEED:-}" ]; then
        # Deterministic pick from seed
        idx=$(( CLIFX_GAME_SEED % len ))
    else
        idx=$(( RANDOM % len ))
    fi

    echo "$pool" | jq -r ".[$idx]"
}

# Public provider interface. Signature matches llm.sh::llm_chat.
provider_chat() {
    local _system_prompt="${1:-}"
    local _transcript="${2:-[]}"
    local _user_message="${3:-}"

    _canned_require || return 1

    local scene stance
    IFS=$'\t' read -r scene stance < <(_canned_context)

    _canned_pick "$scene" "$stance"
}

# Expose a direct endings lookup (used by scene.sh for ending keystones).
canned_ending() {
    local ending="${1:?usage: canned_ending <release|preserve|silence>}"
    _canned_require || return 1

    local pool
    pool=$(jq -c --arg e "$ending" '.endings[$e] // []' "$_CANNED_RESPONSES")
    local len; len=$(echo "$pool" | jq 'length')
    [ "$len" -lt 1 ] && return 1

    local idx
    if [ -n "${CLIFX_GAME_SEED:-}" ]; then
        idx=$(( CLIFX_GAME_SEED % len ))
    else
        idx=$(( RANDOM % len ))
    fi
    echo "$pool" | jq -r ".[$idx]"
}

# Expose a decline-graceful lookup (used when player says "no" to enrichment).
canned_decline() {
    _canned_require || return 1
    local pool; pool=$(jq -c '.decline // []' "$_CANNED_RESPONSES")
    local len; len=$(echo "$pool" | jq 'length')
    [ "$len" -lt 1 ] && return 1

    local idx
    if [ -n "${CLIFX_GAME_SEED:-}" ]; then
        idx=$(( CLIFX_GAME_SEED % len ))
    else
        idx=$(( RANDOM % len ))
    fi
    echo "$pool" | jq -r ".[$idx]"
}
