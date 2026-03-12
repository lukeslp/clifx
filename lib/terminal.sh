#!/usr/bin/env bash
# ============================================================================
# terminal.sh — Terminal Operations
# Purpose: Cursor and screen management primitives
# Depends: core.sh
# ============================================================================

[[ -n "${_CLIFX_TERMINAL_LOADED:-}" ]] && return 0
_CLIFX_TERMINAL_LOADED=1

# --- Cursor visibility ---
hide_cursor() { printf '\033[?25l'; }
show_cursor() { printf '\033[?25h'; }

# Ensure cursor is restored on exit (idempotent — won't stack traps)
if [[ -z "${_CLIFX_CURSOR_TRAP_SET:-}" ]]; then
    trap 'show_cursor' EXIT
    _CLIFX_CURSOR_TRAP_SET=1
fi

# --- Cursor movement ---
move_cursor() { printf "\033[${1};${2}H"; }
save_cursor() { printf '\033[s'; }
restore_cursor() { printf '\033[u'; }

# --- Line / screen clearing ---
clear_line() { printf '\033[2K'; }
clear_to_eol() { printf '\033[K'; }
clear_screen() { printf '\033[2J\033[H'; }

# --- Terminal size ---
# Refresh TERM_COLS and TERM_ROWS from the terminal
get_terminal_size() {
    _clifx_refresh_dimensions
    _clifx_compute_content_width
}

# --- Centering calculations ---

# Calculate the column to start printing centered text
# Usage: center_col "some text"
# Returns: column number via stdout
center_col() {
    local text="$1"
    local text_len=${#text}
    local col=$(( (TERM_COLS - text_len) / 2 ))
    [[ "$col" -lt 1 ]] && col=1
    echo "$col"
}

# Calculate the center row
center_row() {
    echo $(( TERM_ROWS / 2 ))
}

# --- Size validation ---

# Warn if terminal is too small
# Usage: ensure_min_size [min_width] [min_height]
ensure_min_size() {
    local min_w=${1:-$MIN_WIDTH}
    local min_h=${2:-20}

    get_terminal_size

    if [[ "$TERM_COLS" -lt "$min_w" || "$TERM_ROWS" -lt "$min_h" ]]; then
        printf '%b' "${UI_WARN:-\033[33m}"
        echo "Terminal too small: ${TERM_COLS}x${TERM_ROWS} (need ${min_w}x${min_h})"
        printf '%b' "${RESET:-\033[0m}"
        return 1
    fi
    return 0
}
