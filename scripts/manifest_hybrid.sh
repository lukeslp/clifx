#!/usr/bin/env bash
# ============================================================================
# manifest_hybrid.sh — Hybrid Bash/Python Effect Wrappers
#
# Purpose: Provide high-performance versions of computationally intensive
#          effects by delegating to Python helpers in tools/effects/.
#          Each function checks for Python availability and falls back to
#          the pure-Bash implementation if Python is not present.
#
# Effects: plasma_hd, rain_hd
# Sourced by manifest.sh — do not run directly.
# ============================================================================

[[ -n "${_CLIFX_MANIFEST_HYBRID_LOADED:-}" ]] && return 0
_CLIFX_MANIFEST_HYBRID_LOADED=1

# Resolve the tools/effects directory relative to this script
_HYBRID_TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../tools/effects" && pwd)"

# ---------------------------------------------------------------------------
# Internal: check Python availability
# ---------------------------------------------------------------------------
_hybrid_has_python() {
    command -v python3 &>/dev/null
}

# ---------------------------------------------------------------------------
# Internal: map CLIFX_COLOR_FG to a 0.0-1.0 hue value for Python helpers.
# Falls back to green (0.33) if the color cannot be parsed.
# ---------------------------------------------------------------------------
_hybrid_color_to_hue() {
    local color_mode="${1:-default}"
    case "$color_mode" in
        default)   echo "0.33" ;;  # neon green
        cyan)      echo "0.50" ;;
        red)       echo "0.00" ;;
        purple)    echo "0.78" ;;
        white)     echo "0.00" ;;  # white — hue irrelevant at low saturation
        amber)     echo "0.10" ;;
        blue)      echo "0.62" ;;
        pink)      echo "0.88" ;;
        *)         echo "0.33" ;;
    esac
}

# ---------------------------------------------------------------------------
# effect_plasma_hd — High-performance plasma field (Python-backed)
#
# Usage: effect_plasma_hd [duration] [speed_ms]
#
# Delegates to tools/effects/plasma.py for true-color, smooth sine-wave
# plasma rendering. Falls back to effect_plasma (Bash) if Python is absent.
# ---------------------------------------------------------------------------
effect_plasma_hd() {
    local duration=${1:-4}
    local speed=${2:-30}

    if ! _hybrid_has_python; then
        printf "  ${UI_WARN}[hybrid] Python not found — falling back to Bash plasma${RESET}\n" >&2
        effect_plasma "$duration" "$speed"
        return
    fi

    local script="$_HYBRID_TOOLS_DIR/plasma.py"
    if [[ ! -f "$script" ]]; then
        printf "  ${UI_WARN}[hybrid] plasma.py not found at %s — falling back${RESET}\n" "$script" >&2
        effect_plasma "$duration" "$speed"
        return
    fi

    local hue
    hue=$(_hybrid_color_to_hue "${COLOR_MODE:-default}")

    # Apply CLIFX_SPEED_MULT to the frame delay
    local actual_speed=$speed
    if [[ -n "${CLIFX_SPEED_MULT:-}" ]] && [[ "$CLIFX_SPEED_MULT" -ne 100 ]]; then
        actual_speed=$(( speed * CLIFX_SPEED_MULT / 100 ))
        [[ "$actual_speed" -lt 1 ]] && actual_speed=1
    fi

    hide_cursor
    trap 'show_cursor; printf "\033[0m"' EXIT INT TERM

    python3 "$script" \
        --duration "$duration" \
        --speed    "$actual_speed" \
        --cols     "$TERM_COLS" \
        --rows     "$TERM_ROWS" \
        --hue      "$hue"

    show_cursor
}

# ---------------------------------------------------------------------------
# effect_rain_hd — High-performance matrix rain (Python-backed)
#
# Usage: effect_rain_hd [duration] [density]
#   duration: seconds (default: 5)
#   density:  drop density as % of columns (default: 20)
#
# Delegates to tools/effects/rain.py for true-color, smooth rain with
# Katakana characters and proper sub-row velocity. Falls back to
# effect_rain (Bash) if Python is absent.
# ---------------------------------------------------------------------------
effect_rain_hd() {
    local duration=${1:-5}
    local density=${2:-20}

    if ! _hybrid_has_python; then
        printf "  ${UI_WARN}[hybrid] Python not found — falling back to Bash rain${RESET}\n" >&2
        effect_rain "$duration" "$density"
        return
    fi

    local script="$_HYBRID_TOOLS_DIR/rain.py"
    if [[ ! -f "$script" ]]; then
        printf "  ${UI_WARN}[hybrid] rain.py not found at %s — falling back${RESET}\n" "$script" >&2
        effect_rain "$duration" "$density"
        return
    fi

    local hue
    hue=$(_hybrid_color_to_hue "${COLOR_MODE:-default}")

    local speed_mult="${CLIFX_SPEED_MULT:-100}"

    hide_cursor
    trap 'show_cursor; printf "\033[0m"' EXIT INT TERM

    python3 "$script" \
        --duration   "$duration" \
        --density    "$density" \
        --cols       "$TERM_COLS" \
        --rows       "$TERM_ROWS" \
        --hue        "$hue" \
        --speed-mult "$speed_mult"

    show_cursor
}
