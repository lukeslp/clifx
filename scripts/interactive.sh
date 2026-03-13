#!/usr/bin/env bash
# ============================================================================
# scripts/interactive.sh — Interactive Mode Launcher
#
# Purpose: Standalone entry point for clifx interactive widgets.
#          Exposes the iloop_* widgets as named commands.
#
# Usage:
#   bash scripts/interactive.sh counter
#   bash scripts/interactive.sh cursor [symbol]
#   bash scripts/interactive.sh paint  [brush_char]
#   bash scripts/interactive.sh help
#
# Or via the top-level CLI:
#   ./clifx interactive counter
#   ./clifx interactive cursor ◈
#   ./clifx interactive paint  ░
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/../lib/core.sh"
source_lib style terminal text interactive
source_theme default

COLS=$TERM_COLS
ROWS=$TERM_ROWS

_imode_help() {
    printf "\n"
    printf "  ${BOLD}clifx interactive${RESET} — keyboard-driven terminal widgets\n\n"
    printf "  ${UI_ACCENT}Widgets:${RESET}\n"
    printf "    ${BOLD}counter${RESET}           Arrow keys increment/decrement a number\n"
    printf "    ${BOLD}cursor${RESET} [symbol]   Move a character around the screen\n"
    printf "    ${BOLD}paint${RESET}  [char]     Freehand paint with arrow keys + space\n"
    printf "\n"
    printf "  ${UI_DIM}All widgets exit on q/Q/Escape.${RESET}\n\n"
}

widget="${1:-help}"
shift || true

case "$widget" in
    counter)
        iloop_widget_counter "${1:-Counter}"
        ;;
    cursor)
        iloop_widget_cursor "${1:-◈}"
        ;;
    paint)
        iloop_widget_paint "${1:-█}"
        ;;
    help|--help|-h)
        _imode_help
        ;;
    *)
        printf "Unknown widget: %s\n" "$widget" >&2
        _imode_help
        exit 1
        ;;
esac
