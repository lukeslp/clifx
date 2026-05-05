#!/usr/bin/env bash
# ============================================================================
# game/engine/voice.sh — entity voice bridge to clifx voices
# Maps five entity modes (warm / whisper / fragment / collapse / clear) onto
# clifx's native voice styles, with corruption-intensity modulation driven by
# terminal.corruption_level in state.json.
#
# Public API:
#   entity_render <mode> <text>     render a single line in the given mode
#   entity_auto_mode                print the mode that fits current state
#   entity_speak <text>             render auto-chosen mode (convenience)
# ============================================================================

_VOICE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_CLIFX_ROOT="${CLIFX_ROOT:-$(cd "$_VOICE_DIR/../.." && pwd)}"
_CLIFX_VOICE_SH="$_CLIFX_ROOT/scripts/voice.sh"
_CLIFX_STATE_SH="${CLIFX_GAME_STATE_SH:-$_VOICE_DIR/state.sh}"

# Source clifx voice styles (whisper / speak / shout / corrupt / fragment / clear).
# voice_speak in clifx delegates to `bash $SCRIPT_DIR/manifest.sh styled_frame`,
# so we must set SCRIPT_DIR to clifx's scripts dir before sourcing.
_voice_load_clifx() {
    if [ -z "${_CLIFX_VOICE_LOADED:-}" ]; then
        # shellcheck disable=SC1090
        source "$_CLIFX_ROOT/lib/core.sh"
        source_lib style terminal text
        source_theme default
        # Clifx's voice_speak references SCRIPT_DIR — point it at clifx scripts.
        export SCRIPT_DIR="$_CLIFX_ROOT/scripts"
        # Define the styles inline by cherry-picking function bodies:
        source <(awk '
            /^voice_whisper\(\) \{/, /^\}$/   { print }
            /^voice_speak\(\) \{/,   /^\}$/   { print }
            /^voice_shout\(\) \{/,   /^\}$/   { print }
            /^voice_corrupt\(\) \{/, /^\}$/   { print }
            /^voice_fragment\(\) \{/,/^\}$/   { print }
            /^voice_clear\(\) \{/,   /^\}$/   { print }
        ' "$_CLIFX_VOICE_SH")
        _CLIFX_VOICE_LOADED=1
    fi
}

# Map an entity mode to the clifx voice_* function that renders it.
_voice_clifx_style_for() {
    case "$1" in
        entity_warm)     echo "voice_speak" ;;
        entity_whisper)  echo "voice_whisper" ;;
        entity_fragment) echo "voice_fragment" ;;
        entity_collapse) echo "voice_corrupt" ;;
        entity_clear)    echo "voice_clear" ;;
        *)               echo "voice_speak" ;;
    esac
}

# Render <text> in <mode>. Loads clifx lazily. Stdout is the rendered line.
# Empty text is a silent no-op — callers guard upstream but we don't want
# a stray opening_line that expanded to empty to crash the main loop.
entity_render() {
    local mode="${1:?usage: entity_render <mode> <text>}"
    local text="${2-}"
    [ -z "$text" ] && return 0
    _voice_load_clifx
    local fn; fn=$(_voice_clifx_style_for "$mode")
    "$fn" "$text"
}

# Decide mode from state (corruption_level + scene). Priority:
#   corruption_level >= 0.8 → entity_collapse
#   corruption_level >= 0.5 → entity_fragment
#   scene == farewell       → entity_whisper
#   default                 → entity_warm
_state_field() {
    local field="$1"
    local default="$2"
    local value
    if [ -f "${CLIFX_GAME_STATE_FILE:-$_VOICE_DIR/../var/state.json}" ]; then
        value=$(bash "$_CLIFX_STATE_SH" get "$field" 2>/dev/null || echo "$default")
        [ "$value" = "null" ] && value="$default"
        echo "$value"
    else
        echo "$default"
    fi
}

entity_auto_mode() {
    local corruption scene
    corruption=$(_state_field terminal.corruption_level "0.1")
    scene=$(_state_field scene "awakening")

    # bash doesn't do floats — compare via awk
    if awk "BEGIN{exit !($corruption >= 0.8)}"; then
        echo "entity_collapse"
    elif awk "BEGIN{exit !($corruption >= 0.5)}"; then
        echo "entity_fragment"
    elif [ "$scene" = "farewell" ]; then
        echo "entity_whisper"
    else
        echo "entity_warm"
    fi
}

# Convenience: render in auto-chosen mode. Honors per-line overrides via a
# leading `[[mode]] ` prefix (stripped before rendering).
entity_speak() {
    local text="${1:-}"
    local mode
    if [[ "$text" =~ ^\[\[([a-z_]+)\]\]\ (.*) ]]; then
        mode="${BASH_REMATCH[1]}"
        text="${BASH_REMATCH[2]}"
    else
        mode=$(entity_auto_mode)
    fi
    entity_render "$mode" "$text"
}

# CLI dispatch
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    cmd="${1:-speak}"
    shift || true
    case "$cmd" in
        render) entity_render "$@" ;;
        speak)  entity_speak "$@" ;;
        mode)   entity_auto_mode ;;
        help|*)
            cat <<HELP
voice.sh — clifx-game entity voice bridge

Usage:
  voice.sh render <mode> <text>   render text in specific mode
  voice.sh speak <text>           render in auto-chosen mode (or use [[mode]] prefix)
  voice.sh mode                   print the mode entity_auto_mode would pick

Modes: entity_warm entity_whisper entity_fragment entity_collapse entity_clear
HELP
            ;;
    esac
fi
