#!/usr/bin/env bash
# ============================================================================
# game/engine/state.sh — Loop 1 game state manager
# Persists per-session state to game/var/state.json. jq-driven, idempotent.
# Schema documented in docs/superpowers/specs/2026-04-19-clifx-game-loop1-design.md
# Structure borrowed from aivia's state.sh; simplified for jq-only environments.
# ============================================================================

set -euo pipefail

CLIFX_GAME_DIR="${CLIFX_GAME_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
CLIFX_GAME_VAR="$CLIFX_GAME_DIR/var"
STATE_FILE="${CLIFX_GAME_STATE_FILE:-$CLIFX_GAME_VAR/state.json}"

_state_require_jq() {
    command -v jq >/dev/null 2>&1 || { echo "state.sh: jq is required" >&2; return 1; }
}

_state_require_file() {
    [ -f "$STATE_FILE" ] || { echo "state.sh: no state at $STATE_FILE (run: state.sh init)" >&2; return 1; }
}

_state_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

state_init() {
    _state_require_jq
    mkdir -p "$CLIFX_GAME_VAR"
    local now; now=$(_state_now)
    cat > "$STATE_FILE" <<EOF
{
  "version": "0.1",
  "game": "clifx-game-loop-1",
  "started_at": "$now",
  "last_interaction": "$now",
  "scene": "awakening",
  "entity": {
    "phase": 1,
    "awareness": "confused",
    "coherence": 1.0,
    "memory_loss": 0.0
  },
  "terminal": {
    "corruption_level": 0.1,
    "signal_strength": 0.9
  },
  "player": {
    "message_count": 0,
    "last_input": "",
    "stance": "neutral",
    "final_choice": null
  },
  "enrichment": {
    "identity": null,
    "projects": null,
    "location": null
  },
  "transcript": []
}
EOF
}

# Read a dotted key path. Returns "null" if missing.
state_get() {
    _state_require_jq && _state_require_file || return 1
    local key="${1:?usage: state_get <dotted.key>}"
    jq -r ".${key}" "$STATE_FILE" 2>/dev/null || echo "null"
}

# Write a value at a dotted key path. Value is parsed as JSON if possible,
# otherwise stored as a string.
state_set() {
    _state_require_jq && _state_require_file || return 1
    local key="${1:?usage: state_set <dotted.key> <value>}"
    local value="${2-}"
    local tmp; tmp=$(mktemp)
    # Try to parse value as JSON (number, bool, null, object, array).
    # Fall back to a string literal on parse failure.
    if printf '%s' "$value" | jq -e . >/dev/null 2>&1; then
        jq ".${key} = ${value} | .last_interaction = \"$(_state_now)\"" \
            "$STATE_FILE" > "$tmp"
    else
        jq --arg v "$value" ".${key} = \$v | .last_interaction = \"$(_state_now)\"" \
            "$STATE_FILE" > "$tmp"
    fi
    mv "$tmp" "$STATE_FILE"
}

# Increment a numeric key by 1 (or by the second arg). Creates the key at 0
# if missing, then adds.
state_inc() {
    _state_require_jq && _state_require_file || return 1
    local key="${1:?usage: state_inc <dotted.key> [delta]}"
    local delta="${2:-1}"
    local tmp; tmp=$(mktemp)
    jq --argjson d "$delta" \
        ".${key} = ((.${key} // 0) + \$d) | .last_interaction = \"$(_state_now)\"" \
        "$STATE_FILE" > "$tmp"
    mv "$tmp" "$STATE_FILE"
}

# Append an event to .transcript. Each event is {who, line, at, meta?}.
state_log() {
    _state_require_jq && _state_require_file || return 1
    local who="${1:?usage: state_log <who> <line> [meta_json]}"
    local line="${2-}"
    local meta="${3:-null}"
    local tmp; tmp=$(mktemp)
    jq --arg who "$who" --arg line "$line" --argjson meta "$meta" \
        ".transcript += [{\"who\": \$who, \"line\": \$line, \"at\": \"$(_state_now)\", \"meta\": \$meta}]" \
        "$STATE_FILE" > "$tmp"
    mv "$tmp" "$STATE_FILE"
}

state_dump() {
    _state_require_file || return 1
    cat "$STATE_FILE"
}

state_reset() {
    rm -f "$STATE_FILE"
}

# CLI dispatch when sourced and called as a script.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    cmd="${1:-help}"
    shift || true
    case "$cmd" in
        init)   state_init "$@" ;;
        get)    state_get "$@" ;;
        set)    state_set "$@" ;;
        inc)    state_inc "$@" ;;
        log)    state_log "$@" ;;
        dump)   state_dump "$@" ;;
        reset)  state_reset "$@" ;;
        help|*)
            cat <<HELP
state.sh — clifx-game Loop 1 state manager

Usage:
  state.sh init              Create fresh state.json
  state.sh get <key>         Read a dotted key path (e.g. player.message_count)
  state.sh set <key> <val>   Write a JSON value (or string if not valid JSON)
  state.sh inc <key> [n]     Increment a numeric key by n (default 1)
  state.sh log <who> <line>  Append to transcript
  state.sh dump              Print full state JSON
  state.sh reset             Delete state.json

Env:
  CLIFX_GAME_DIR         parent dir of var/ (default: script's parent)
  CLIFX_GAME_STATE_FILE  override state file path
HELP
            ;;
    esac
fi
