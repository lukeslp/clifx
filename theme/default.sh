#!/usr/bin/env bash
# ============================================================================
# default.sh — Default Theme (Neon Green)
# Purpose: Theme colors, frame characters, and themed utilities
# Depends: core.sh, style.sh
# ============================================================================

[[ -n "${_CLIFX_THEME_DEFAULT_LOADED:-}" ]] && return 0
_CLIFX_THEME_DEFAULT_LOADED=1

# --- Theme Palette ---
# Each can be overridden via CLIFX_COLOR_* env vars (for testing/theming)
THEME_FG="${CLIFX_COLOR_FG:-\033[38;5;48m}"        # Bright toxic green
THEME_DIM="${CLIFX_COLOR_DIM:-\033[38;5;22m}"      # Dark forest green
THEME_ACCENT="${CLIFX_COLOR_ACCENT:-\033[38;5;93m}" # Deep purple
THEME_WARN="${CLIFX_COLOR_WARN:-\033[38;5;196m}"   # Red
THEME_BG='\033[48;5;0m'                             # Pure black background
THEME_GLOW="${CLIFX_COLOR_GLOW:-\033[38;5;83m}"    # Phosphor green (bright/active state)

# --- Frame Characters ---
FRAME_CHAR_SET=('░' '▒' '▓' '█' '◈' '◆' '▲' '∷' '∴' '⊹' '⊛' '⌇')

# --- Theme Functions ---

# Pick a random frame character
random_frame_char() {
    echo "${FRAME_CHAR_SET[$((RANDOM % ${#FRAME_CHAR_SET[@]}))]}"
}

# Generate a border string from random frame chars
# Usage: theme_border <width>
theme_border() {
    local width=$1
    local border=""
    for ((i=0; i<width; i++)); do
        border+="$(random_frame_char)"
    done
    echo "$border"
}

# Themed divider (random frame chars)
# Usage: theme_divider [width] [color]
theme_divider() {
    local width="${1:-$CONTENT_WIDTH}"
    local color="${2:-$THEME_FG}"

    printf '%b' "$color"
    for ((i=0; i<width; i++)); do
        printf "%s" "$(random_frame_char)"
    done
    printf '%b' "$RESET"
    echo ""
}
