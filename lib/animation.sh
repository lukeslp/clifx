#!/usr/bin/env bash
# ============================================================================
# animation.sh — Animation Primitives
# Purpose: Core building blocks for visual effects
# Depends: core.sh, style.sh, terminal.sh
# ============================================================================

[[ -n "${_CLIFX_ANIMATION_LOADED:-}" ]] && return 0
_CLIFX_ANIMATION_LOADED=1

# --- Sweep down ---
# Wipe effect from top to bottom
# Usage: sweep_down [char] [color] [speed_ms]
sweep_down() {
    local char="${1:-░}"
    local color="${2:-$DIM}"
    local speed=${3:-15}

    hide_cursor
    for ((row=1; row<=TERM_ROWS; row++)); do
        move_cursor "$row" 1
        printf '%b' "$color"
        for ((col=0; col<TERM_COLS; col++)); do
            printf "%s" "$char"
        done
        printf '%b' "$RESET"
        sleep_ms "$speed"
    done
    show_cursor
}

# --- Sweep up ---
# Wipe effect from bottom to top
# Usage: sweep_up [char] [color] [speed_ms]
sweep_up() {
    local char="${1:-░}"
    local color="${2:-$DIM}"
    local speed=${3:-15}

    hide_cursor
    for ((row=TERM_ROWS; row>=1; row--)); do
        move_cursor "$row" 1
        printf '%b' "$color"
        for ((col=0; col<TERM_COLS; col++)); do
            printf "%s" "$char"
        done
        printf '%b' "$RESET"
        sleep_ms "$speed"
    done
    show_cursor
}

# --- Pulse ---
# Throb text between colors at a position
# Usage: pulse "text" <row> <col> [count] [color1] [color2]
pulse() {
    local text="$1"
    local row=$2
    local col=$3
    local count=${4:-5}
    local color_bright="${5:-$BOLD}"
    local color_dim="${6:-$DIM}"

    hide_cursor
    for ((i=0; i<count; i++)); do
        # Bright
        move_cursor "$row" "$col"
        printf '%b%s%b' "$color_bright" "$text" "$RESET"
        sleep_ms 200

        # Dim
        move_cursor "$row" "$col"
        printf '%b%s%b' "$color_dim" "$text" "$RESET"
        sleep_ms 600
    done
    show_cursor
}

# --- Flash screen ---
# Reverse video flash effect
# Usage: flash_screen [count]
flash_screen() {
    local count=${1:-5}
    hide_cursor
    for ((i=0; i<count; i++)); do
        printf '\033[?5h'  # Reverse video mode
        sleep_ms $(random_int 30 120)
        printf '\033[?5l'  # Normal video mode
        sleep_ms $(random_int 50 300)
    done
    show_cursor
}

# --- Fill random ---
# Scatter random characters across the screen
# Usage: fill_random <chars_string> [color] [density] [duration_ms]
# chars_string: characters to scatter, e.g. "░▒▓█"
fill_random() {
    local chars="$1"
    local color="${2:-}"
    local density=${3:-30}   # percentage of cells to fill
    local duration=${4:-500}

    local total_cells=$((TERM_COLS * TERM_ROWS))
    local fill_count=$((total_cells * density / 100))
    local chars_len=${#chars}

    hide_cursor
    [[ -n "$color" ]] && printf '%b' "$color"

    for ((i=0; i<fill_count; i++)); do
        local row=$(random_int 1 "$TERM_ROWS")
        local col=$(random_int 1 "$TERM_COLS")
        local ci=$((RANDOM % chars_len))
        move_cursor "$row" "$col"
        printf "%s" "${chars:$ci:1}"
    done

    [[ -n "$color" ]] && printf '%b' "$RESET"
    show_cursor
}

# --- Clear sweep ---
# Animated clear in a direction
# Usage: clear_sweep [down|up] [speed_ms]
clear_sweep() {
    local direction="${1:-down}"
    local speed=${2:-10}

    hide_cursor
    if [[ "$direction" == "down" ]]; then
        for ((row=1; row<=TERM_ROWS; row++)); do
            move_cursor "$row" 1
            clear_line
            sleep_ms "$speed"
        done
    else
        for ((row=TERM_ROWS; row>=1; row--)); do
            move_cursor "$row" 1
            clear_line
            sleep_ms "$speed"
        done
    fi
    show_cursor
}
