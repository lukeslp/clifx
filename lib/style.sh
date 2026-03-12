#!/usr/bin/env bash
# ============================================================================
# style.sh — Colors & ANSI Codes
# Purpose: Centralized color/style definitions
# Depends: core.sh
# ============================================================================

[[ -n "${_CLIFX_STYLE_LOADED:-}" ]] && return 0
_CLIFX_STYLE_LOADED=1

# --- Reset & Modifiers ---
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
ITALIC='\033[3m'
UNDERLINE='\033[4m'
BLINK='\033[5m'
REVERSE='\033[7m'
HIDDEN='\033[8m'
STRIKETHROUGH='\033[9m'

# --- Standard UI Colors ---
UI_FG='\033[37m'          # Default foreground (white)
UI_DIM='\033[38;5;245m'   # Medium gray (legible on dark backgrounds)
UI_ACCENT='\033[36m'      # Cyan accent
UI_SUCCESS='\033[32m'     # Green
UI_WARN='\033[33m'        # Yellow
UI_ERROR='\033[31m'       # Red
UI_INFO='\033[34m'        # Blue

# --- Color Construction ---

# Build 256-color foreground code
# Usage: fg 48
fg() {
    printf '\033[38;5;%dm' "$1"
}

# Build 256-color background code
# Usage: bg 0
bg() {
    printf '\033[48;5;%dm' "$1"
}

# Convert RGB to nearest 256-color index
# Usage: color_256 <r> <g> <b>  (0-255 each)
color_256() {
    local r=$1 g=$2 b=$3
    # Map to 6x6x6 color cube (indices 16-231)
    local ri=$(( (r * 5 + 127) / 255 ))
    local gi=$(( (g * 5 + 127) / 255 ))
    local bi=$(( (b * 5 + 127) / 255 ))
    echo $(( 16 + ri * 36 + gi * 6 + bi ))
}

# Build foreground from RGB
# Usage: fg_rgb 0 255 128
fg_rgb() {
    printf '\033[38;5;%dm' "$(color_256 "$1" "$2" "$3")"
}

# Build background from RGB
# Usage: bg_rgb 0 0 0
bg_rgb() {
    printf '\033[48;5;%dm' "$(color_256 "$1" "$2" "$3")"
}

# Full style reset
style_reset() {
    printf '%b' "$RESET"
}

# --- Capability Detection ---

# Check if terminal supports 256 colors
supports_256_color() {
    local colors
    colors=$(tput colors 2>/dev/null || echo 0)
    [[ "$colors" -ge 256 ]]
}

# Check if terminal supports 24-bit truecolor
supports_truecolor() {
    [[ "${COLORTERM:-}" == "truecolor" || "${COLORTERM:-}" == "24bit" ]]
}
