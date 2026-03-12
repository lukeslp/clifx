#!/usr/bin/env bash
# ============================================================================
# divider.sh — Horizontal Rules & Section Breaks
# Purpose: Full-width dividers in various styles
# Depends: core.sh, style.sh
# ============================================================================

[[ -n "${_CLIFX_DIVIDER_LOADED:-}" ]] && return 0
_CLIFX_DIVIDER_LOADED=1

# --- Divider ---
# Usage: divider [style] [color] [width]
# Styles: thin, thick, double, dotted, dashed, wave
divider() {
    local style="${1:-thin}"
    local color="${2:-}"
    local width="${3:-$CONTENT_WIDTH}"
    local char

    case "$style" in
        thin)   char='─' ;;
        thick)  char='━' ;;
        double) char='═' ;;
        dotted) char='·' ;;
        dashed) char='╌' ;;
        wave)   char='~' ;;
        *)      char='─' ;;
    esac

    [[ -n "$color" ]] && printf '%b' "$color"
    for ((i=0; i<width; i++)); do
        printf "%s" "$char"
    done
    [[ -n "$color" ]] && printf '%b' "$RESET"
    echo ""
}

# --- Divider with centered text ---
# Usage: divider_text "Section Title" [style] [color]
divider_text() {
    local text="$1"
    local style="${2:-thin}"
    local color="${3:-}"
    local width="$CONTENT_WIDTH"
    local char

    case "$style" in
        thin)   char='─' ;;
        thick)  char='━' ;;
        double) char='═' ;;
        dotted) char='·' ;;
        dashed) char='╌' ;;
        wave)   char='~' ;;
        *)      char='─' ;;
    esac

    local text_len=${#text}
    local side_len=$(( (width - text_len - 2) / 2 ))
    [[ "$side_len" -lt 1 ]] && side_len=1

    [[ -n "$color" ]] && printf '%b' "$color"

    for ((i=0; i<side_len; i++)); do
        printf "%s" "$char"
    done
    printf " %s " "$text"
    # Right side — fill remaining
    local right_len=$((width - side_len - text_len - 2))
    for ((i=0; i<right_len; i++)); do
        printf "%s" "$char"
    done

    [[ -n "$color" ]] && printf '%b' "$RESET"
    echo ""
}

# --- Blank lines ---
# Usage: blank_lines 3
blank_lines() {
    local n=${1:-1}
    for ((i=0; i<n; i++)); do
        echo ""
    done
}
