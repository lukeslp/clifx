#!/usr/bin/env bash
# ============================================================================
# play.sh — ASCII Frame Animation Player
# Purpose: Play frame-delimited ASCII animations from text files
# Usage:
#   bash scripts/play.sh <file.txt> [fps] [loops]
#   bash scripts/play.sh ascii-animations/spiral.txt
#   bash scripts/play.sh ascii-animations/gears.txt 24 0   # 24fps, loop forever
#
# File format: Frames separated by "--- Frame N ---" delimiter lines.
# Press Ctrl+C to stop.
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"
source_lib style terminal ascii

FILE="${1:?Usage: bash scripts/play.sh <file> [fps] [loops]}"
FPS="${2:-12}"
LOOPS="${3:-1}"

# Resolve relative paths from project root
if [[ ! -f "$FILE" ]] && [[ -f "$SCRIPT_DIR/../$FILE" ]]; then
    FILE="$SCRIPT_DIR/../$FILE"
fi

# Restore cursor on exit
trap 'show_cursor; printf "\033[0m"' EXIT INT TERM

play_frames "$FILE" "$FPS" "$LOOPS"
