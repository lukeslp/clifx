#!/usr/bin/env bash
# ============================================================================
# core.sh — Bootstrap & Constants
# Purpose: Foundation for all clifx lib files. Source this first.
# Usage: source "path/to/lib/core.sh"
# ============================================================================

# Guard against double-sourcing
[[ -n "${_CLIFX_CORE_LOADED:-}" ]] && return 0
_CLIFX_CORE_LOADED=1

# --- LIB_DIR detection ---
# Find the lib directory relative to wherever this file is sourced from
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    _CLIFX_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    _CLIFX_LIB_DIR="${_CLIFX_LIB_DIR:-$(pwd)/lib}"
fi
readonly CLIFX_LIB_DIR="$_CLIFX_LIB_DIR"
readonly CLIFX_ROOT_DIR="$(dirname "$CLIFX_LIB_DIR")"

# --- Terminal dimensions ---
_clifx_refresh_dimensions() {
    TERM_COLS=$(tput cols 2>/dev/null || echo 80)
    TERM_ROWS=$(tput lines 2>/dev/null || echo 24)
}
_clifx_refresh_dimensions

# --- Dimension constants ---
readonly MIN_WIDTH=40
readonly MAX_WIDTH=120
readonly STANDARD_WIDTH=80

# CONTENT_WIDTH: dynamically computed as min(TERM_COLS, MAX_WIDTH)
_clifx_compute_content_width() {
    if [ "$TERM_COLS" -le "$MAX_WIDTH" ]; then
        CONTENT_WIDTH=$TERM_COLS
    else
        CONTENT_WIDTH=$MAX_WIDTH
    fi
}
_clifx_compute_content_width

# --- Cross-platform millisecond sleep ---
# Honors CLIFX_SPEED_MULT env var (percentage: 50=2x faster, 200=2x slower)
sleep_ms() {
    local ms=$1
    if [[ -n "${CLIFX_SPEED_MULT:-}" ]] && [[ "$CLIFX_SPEED_MULT" -ne 100 ]]; then
        ms=$(( ms * CLIFX_SPEED_MULT / 100 ))
        [[ "$ms" -lt 1 ]] && ms=1
    fi
    if command -v python3 &>/dev/null; then
        python3 -c "import time; time.sleep($ms/1000.0)"
    else
        sleep "0.$(printf '%03d' "$ms")"
    fi
}

# --- Source other lib files ---
# Usage: source_lib style terminal text
source_lib() {
    local mod
    for mod in "$@"; do
        local path="$CLIFX_LIB_DIR/${mod}.sh"
        if [[ -f "$path" ]]; then
            # shellcheck disable=SC1090
            source "$path"
        else
            echo "clifx: lib module not found: $mod ($path)" >&2
            return 1
        fi
    done
}

# --- Source theme files ---
# Usage: source_theme default
source_theme() {
    local mod
    for mod in "$@"; do
        local path="$CLIFX_ROOT_DIR/theme/${mod}.sh"
        if [[ -f "$path" ]]; then
            # shellcheck disable=SC1090
            source "$path"
        else
            echo "clifx: theme not found: $mod ($path)" >&2
            return 1
        fi
    done
}

# --- Random number utility ---
random_int() {
    local min=$1 max=$2
    echo $(( RANDOM % (max - min + 1) + min ))
}

# --- Random choice from array ---
# Usage: random_choice "${array[@]}"
random_choice() {
    local arr=("$@")
    echo "${arr[$((RANDOM % ${#arr[@]}))]}"
}
