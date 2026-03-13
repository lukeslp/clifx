#!/usr/bin/env bash
# ============================================================================
# lib/interactive.sh — Interactive Event Loop
#
# Purpose: Provides a non-blocking keypress event loop for building
#          interactive, real-time terminal experiences on top of clifx.
#          Enables effects that respond to keyboard input without pausing.
#
# Depends: core.sh, style.sh, terminal.sh
#
# Key concepts:
#   - _iloop_read_key: non-blocking single-keypress read (100ms timeout)
#   - iloop_run: main event loop driver — calls user-supplied callbacks
#   - Key constants: IKEY_UP, IKEY_DOWN, IKEY_LEFT, IKEY_RIGHT, IKEY_QUIT, etc.
#
# Usage:
#   source_lib interactive
#
#   # Define callbacks
#   my_update() { local key="$1" dt="$2"; ... }  # called every frame
#   my_draw()   { ...; }                           # called after update
#
#   iloop_run my_update my_draw 30   # 30ms frame budget
# ============================================================================

[[ -n "${_CLIFX_INTERACTIVE_LOADED:-}" ]] && return 0
_CLIFX_INTERACTIVE_LOADED=1

# ---------------------------------------------------------------------------
# Key constants (ANSI escape sequences and printable chars)
# ---------------------------------------------------------------------------
IKEY_UP=$'\033[A'
IKEY_DOWN=$'\033[B'
IKEY_RIGHT=$'\033[C'
IKEY_LEFT=$'\033[D'
IKEY_QUIT='q'
IKEY_QUIT_UPPER='Q'
IKEY_ESC=$'\033'
IKEY_ENTER=$'\n'
IKEY_SPACE=' '
IKEY_NONE=''

# ---------------------------------------------------------------------------
# _iloop_read_key — Non-blocking keypress read
#
# Reads up to 6 bytes from stdin with a short timeout.
# Sets global ILOOP_KEY to the key string (or IKEY_NONE if no input).
# ---------------------------------------------------------------------------
ILOOP_KEY="$IKEY_NONE"

_iloop_read_key() {
    local key=""
    # -s: silent, -n 1: one char, -t 0.05: 50ms timeout
    if IFS= read -r -s -n 1 -t 0.05 key 2>/dev/null; then
        # Check for escape sequences (arrow keys, function keys)
        if [[ "$key" == $'\033' ]]; then
            local seq=""
            # Read up to 5 more bytes with a very short timeout
            IFS= read -r -s -n 5 -t 0.01 seq 2>/dev/null || true
            key="${key}${seq}"
        fi
        ILOOP_KEY="$key"
    else
        ILOOP_KEY="$IKEY_NONE"
    fi
}

# ---------------------------------------------------------------------------
# iloop_run — Main event loop
#
# Usage: iloop_run <update_fn> <draw_fn> [frame_ms]
#
#   update_fn(key, dt_ms): called every frame with the current key and
#                          elapsed time since last frame (milliseconds).
#                          Should return 0 to continue, 1 to exit.
#   draw_fn():             called after update_fn to redraw the screen.
#   frame_ms:              target frame duration in milliseconds (default: 33)
#
# The loop exits when:
#   - update_fn returns non-zero
#   - The user presses q/Q/Escape
#   - SIGINT is received
# ---------------------------------------------------------------------------
iloop_run() {
    local update_fn="$1"
    local draw_fn="$2"
    local frame_ms="${3:-33}"

    hide_cursor
    clear_screen

    local _iloop_running=1

    _iloop_cleanup() {
        _iloop_running=0
        show_cursor
        printf '%b' "$RESET"
    }
    trap '_iloop_cleanup; return 0' INT TERM

    # Restore terminal on exit
    local _old_stty
    _old_stty=$(stty -g 2>/dev/null || true)
    # Put terminal in raw mode so we can read keys without Enter
    stty -echo -icanon min 0 time 0 2>/dev/null || true

    local _last_frame_ms
    _last_frame_ms=$(python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null || echo 0)

    while [[ "$_iloop_running" -eq 1 ]]; do
        local _now_ms
        _now_ms=$(python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null || echo 0)
        local _dt=$(( _now_ms - _last_frame_ms ))
        _last_frame_ms=$_now_ms

        # Read input
        _iloop_read_key

        # Quit on q/Q/Escape
        if [[ "$ILOOP_KEY" == "$IKEY_QUIT" || \
              "$ILOOP_KEY" == "$IKEY_QUIT_UPPER" || \
              "$ILOOP_KEY" == "$IKEY_ESC" ]]; then
            break
        fi

        # Call update callback; exit if it returns non-zero
        if ! "$update_fn" "$ILOOP_KEY" "$_dt"; then
            break
        fi

        # Call draw callback
        "$draw_fn"

        # Frame pacing: sleep remaining budget
        local _elapsed_ms
        _elapsed_ms=$(python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null || echo 0)
        local _remaining=$(( frame_ms - (_elapsed_ms - _now_ms) ))
        if [[ "$_remaining" -gt 0 ]]; then
            sleep_ms "$_remaining"
        fi
    done

    # Restore terminal
    [[ -n "$_old_stty" ]] && stty "$_old_stty" 2>/dev/null || true
    _iloop_cleanup
}

# ---------------------------------------------------------------------------
# iloop_widget_counter — Example interactive widget: a counter
#
# Demonstrates iloop_run usage. Arrow keys increment/decrement.
# Press q to exit.
# ---------------------------------------------------------------------------
iloop_widget_counter() {
    local title="${1:-Counter}"
    local _count=0

    _counter_update() {
        local key="$1"
        case "$key" in
            "$IKEY_UP"|"$IKEY_RIGHT"|"+") _count=$(( _count + 1 )) ;;
            "$IKEY_DOWN"|"$IKEY_LEFT"|"-") _count=$(( _count - 1 )) ;;
        esac
        return 0
    }

    _counter_draw() {
        move_cursor 1 1
        printf "${THEME_DIM}%s${RESET}\n" "$title"
        move_cursor 3 1
        printf "  ${THEME_GLOW}${BOLD}%6d${RESET}\n" "$_count"
        move_cursor 5 1
        printf "  ${UI_DIM}↑/↓ to change  q to quit${RESET}\n"
    }

    iloop_run _counter_update _counter_draw 50
}

# ---------------------------------------------------------------------------
# iloop_widget_cursor — Example interactive widget: a movable cursor
#
# A character the user can move around the screen with arrow keys.
# ---------------------------------------------------------------------------
iloop_widget_cursor() {
    local symbol="${1:-◈}"
    local _cx=$(( TERM_COLS / 2 ))
    local _cy=$(( TERM_ROWS / 2 ))
    local _prev_cx=$_cx
    local _prev_cy=$_cy

    _cursor_update() {
        local key="$1"
        _prev_cx=$_cx
        _prev_cy=$_cy
        case "$key" in
            "$IKEY_UP")    (( _cy > 1 ))          && _cy=$(( _cy - 1 )) ;;
            "$IKEY_DOWN")  (( _cy < TERM_ROWS ))   && _cy=$(( _cy + 1 )) ;;
            "$IKEY_LEFT")  (( _cx > 1 ))           && _cx=$(( _cx - 1 )) ;;
            "$IKEY_RIGHT") (( _cx < TERM_COLS ))   && _cx=$(( _cx + 1 )) ;;
        esac
        return 0
    }

    _cursor_draw() {
        # Erase previous position
        move_cursor "$_prev_cy" "$_prev_cx"
        printf " "
        # Draw at new position
        move_cursor "$_cy" "$_cx"
        printf "${THEME_GLOW}${BOLD}%s${RESET}" "$symbol"
        # Status bar
        move_cursor "$TERM_ROWS" 1
        printf "${UI_DIM}pos: %3d,%3d  arrows to move  q to quit${RESET}" "$_cx" "$_cy"
    }

    iloop_run _cursor_update _cursor_draw 33
}

# ---------------------------------------------------------------------------
# iloop_widget_paint — Freehand paint mode
#
# Move a cursor with arrow keys; press SPACE to paint a character.
# ---------------------------------------------------------------------------
iloop_widget_paint() {
    local brush="${1:-█}"
    local _px=$(( TERM_COLS / 2 ))
    local _py=$(( TERM_ROWS / 2 ))
    local _painting=0

    _paint_update() {
        local key="$1"
        case "$key" in
            "$IKEY_UP")    (( _py > 1 ))          && _py=$(( _py - 1 )) ;;
            "$IKEY_DOWN")  (( _py < TERM_ROWS-1 )) && _py=$(( _py + 1 )) ;;
            "$IKEY_LEFT")  (( _px > 1 ))           && _px=$(( _px - 1 )) ;;
            "$IKEY_RIGHT") (( _px < TERM_COLS ))   && _px=$(( _px + 1 )) ;;
            "$IKEY_SPACE") _painting=1 ;;
            *) _painting=0 ;;
        esac
        return 0
    }

    _paint_draw() {
        if [[ "$_painting" -eq 1 ]]; then
            move_cursor "$_py" "$_px"
            printf "${THEME_FG}%s${RESET}" "$brush"
        fi
        # Cursor indicator
        move_cursor "$_py" "$_px"
        printf "${THEME_GLOW}${BLINK}▮${RESET}"
        # Status bar
        move_cursor "$TERM_ROWS" 1
        printf "${UI_DIM}arrows: move  space: paint  q: quit${RESET}%*s" \
            $(( TERM_COLS - 40 )) ""
    }

    iloop_run _paint_update _paint_draw 33
}
