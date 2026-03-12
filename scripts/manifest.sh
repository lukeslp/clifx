#!/usr/bin/env bash
# ============================================================================
# manifest.sh — CLI Visual Effects Library
# Purpose: Render terminal visual effects
# Usage: bash manifest.sh <effect_name> [args...]
# Effects: glitch, static, flicker, styled_frame, build_text,
#          corruption, heartbeat, transition, color_wave, fake_install,
#          screen_tear, scanlines, chromatic_aberration, signal_noise, datamosh,
#          rain, spiral, ripple, orbit,
#          hex_dump, waveform, process_tree,
#          vignette, plasma, breathe, afterimage, typewriter_rewind,
#          credits
# ============================================================================

set -euo pipefail

# --- Source library ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"
source_lib style terminal text animation ascii
source_theme default

# Source effect modules
for _ef in "$SCRIPT_DIR"/manifest_*.sh; do
    [ -f "$_ef" ] && source "$_ef"
done

# Aliases for convenience
COLS=$TERM_COLS
ROWS=$TERM_ROWS

# --- Effect: glitch ---
# Brief visual disruption with random characters.
effect_glitch() {
    local intensity=${1:-3}  # 1=subtle, 3=moderate, 5=heavy
    local duration=${2:-1}   # seconds

    hide_cursor
    local end_time=$((SECONDS + duration))

    while [ $SECONDS -lt $end_time ]; do
        local row=$(random_int 1 "$ROWS")
        local col=$(random_int 1 "$COLS")
        local char=$(random_frame_char)

        move_cursor "$row" "$col"
        printf "${THEME_FG}%s${RESET}" "$char"
        sleep_ms $((50 / intensity))

        if [ $((RANDOM % (10 / intensity))) -eq 0 ]; then
            local glitch_row=$(random_int 1 "$ROWS")
            move_cursor "$glitch_row" 1
            printf "${REVERSE}${THEME_DIM}"
            for ((i=0; i<COLS; i++)); do
                printf "%s" "$(random_frame_char)"
            done
            printf "${RESET}"
            sleep_ms 80
            move_cursor "$glitch_row" 1
            clear_line
        fi
    done
    show_cursor
}

# --- Effect: static ---
# TV static / snow effect.
effect_static() {
    local duration=${1:-2}
    local chars=('.' ':' '·' '°' '•' ' ' '░')

    hide_cursor
    local end_time=$((SECONDS + duration))

    while [ $SECONDS -lt $end_time ]; do
        for ((row=1; row<=ROWS; row++)); do
            move_cursor "$row" 1
            local line=""
            for ((col=0; col<COLS; col++)); do
                line+="${chars[$((RANDOM % ${#chars[@]}))]}"
            done
            if [ $((RANDOM % 3)) -eq 0 ]; then
                printf "${DIM}%s${RESET}" "$line"
            else
                printf "${THEME_DIM}%s${RESET}" "$line"
            fi
        done
        sleep_ms 40
    done

    for ((row=1; row<=ROWS; row++)); do
        move_cursor "$row" 1
        clear_line
    done
    show_cursor
}

# --- Effect: flicker ---
# Screen flickers on/off via reverse video.
effect_flicker() {
    local count=${1:-5}
    flash_screen "$count"
}

# --- Effect: styled_frame ---
# Bordered frame with character-by-character text rendering.
effect_styled_frame() {
    local text="$1"
    local width=$((COLS - 4))
    local padding=2
    local start_row=${2:-$((ROWS / 3))}

    hide_cursor

    # Top border — builds character by character
    move_cursor "$start_row" "$padding"
    for ((i=0; i<width; i++)); do
        printf "${THEME_FG}%s${RESET}" "$(random_frame_char)"
        sleep_ms 8
    done

    # Side borders + text
    local text_row=$((start_row + 1))
    move_cursor "$text_row" "$padding"
    printf "${THEME_FG}▐${RESET}"
    printf " "

    # Text renders character by character
    local text_len=${#text}
    for ((i=0; i<text_len; i++)); do
        local char="${text:$i:1}"
        if [ $((RANDOM % 40)) -eq 0 ]; then
            printf "${THEME_ACCENT}%s${RESET}" "$(random_frame_char)"
            sleep_ms 60
            printf '\b'
        fi
        printf "${THEME_GLOW}${BOLD}%s${RESET}" "$char"
        sleep_ms $((20 + RANDOM % 30))
    done

    # Fill remaining space
    local remaining=$((width - text_len - 3))
    [ $remaining -gt 0 ] && printf "%*s" "$remaining" ""
    printf "${THEME_FG}▌${RESET}"

    # Bottom border
    local bottom_row=$((text_row + 1))
    move_cursor "$bottom_row" "$padding"
    for ((i=0; i<width; i++)); do
        printf "${THEME_FG}%s${RESET}" "$(random_frame_char)"
        sleep_ms 8
    done

    echo ""
    show_cursor
}

# --- Effect: build_text ---
# Text that types itself out with occasional glitch overlays.
effect_build_text() {
    local text="$1"
    local speed=${2:-30}

    for ((i=0; i<${#text}; i++)); do
        local char="${text:$i:1}"

        # Glitch overlay
        if [ $((RANDOM % 60)) -eq 0 ]; then
            printf "${THEME_ACCENT}%s${RESET}" "$(random_frame_char)"
            sleep_ms 100
            printf '\b'
        fi

        if [ "$char" = $'\n' ]; then
            echo ""
        else
            printf "${THEME_GLOW}%s${RESET}" "$char"
        fi

        case "$char" in
            '.' | '?' | '!') sleep_ms $((speed * 8)) ;;
            ',' | ';' | ':') sleep_ms $((speed * 4)) ;;
            ' ') sleep_ms $((speed * 2)) ;;
            *) sleep_ms "$speed" ;;
        esac
    done
    echo ""
}

# --- Effect: corruption ---
# Display file content with brief glitch line insertions (display only).
effect_corruption() {
    local file_content="$1"
    local glitch_lines=("data corrupted" "signal interrupted" "unexpected input" "buffer overflow" "segfault" "null reference" "stack trace lost")

    local line_num=0
    while IFS= read -r line; do
        line_num=$((line_num + 1))
        if [ $((RANDOM % 5)) -eq 0 ]; then
            local glitch_msg="${glitch_lines[$((RANDOM % ${#glitch_lines[@]}))]}"
            printf "${THEME_FG}${DIM}%4d │ %s${RESET}\n" "$line_num" "$glitch_msg"
            sleep_ms 200
            sleep_ms 400
            printf "\033[1A\033[2K"
            printf "%4d │ %s\n" "$line_num" "$line"
        else
            printf "%4d │ %s\n" "$line_num" "$line"
        fi
        sleep_ms 20
    done <<< "$file_content"
}

# --- Effect: heartbeat ---
# Pulsing symbol at screen center.
effect_heartbeat() {
    local count=${1:-5}
    local symbol=${2:-"◈"}

    hide_cursor
    local center_row=$((ROWS / 2))
    local center_col=$((COLS / 2))

    for ((i=0; i<count; i++)); do
        move_cursor "$center_row" "$center_col"
        printf "${THEME_GLOW}${BOLD} %s ${RESET}" "$symbol"
        sleep_ms 200

        move_cursor "$center_row" "$center_col"
        printf "${THEME_DIM} %s ${RESET}" "$symbol"
        sleep_ms 600
    done

    move_cursor "$center_row" "$center_col"
    printf "   "
    show_cursor
}

# --- Effect: transition ---
# Screen wipe with themed characters.
effect_transition() {
    hide_cursor

    for ((row=1; row<=ROWS; row++)); do
        move_cursor "$row" 1
        for ((col=0; col<COLS; col++)); do
            if [ $((RANDOM % 3)) -eq 0 ]; then
                printf "${THEME_FG}%s${RESET}" "$(random_frame_char)"
            else
                printf "${THEME_DIM}░${RESET}"
            fi
        done
        sleep_ms 15
    done

    sleep_ms 500
    clear_sweep up 10
    show_cursor
}

# --- Effect: color_wave ---
# Color gradient sweeps across the screen.
effect_color_wave() {
    local waves=${1:-3}
    local direction=${2:-down}

    hide_cursor
    save_cursor

    local colors=(22 28 34 40 46 83 83 46 40 34 28 22)

    for ((w=0; w<waves; w++)); do
        if [ "$direction" = "down" ] || [ "$direction" = "up" ]; then
            local start=1 end=$ROWS step=1
            [ "$direction" = "up" ] && start=$ROWS && end=1 && step=-1

            local row=$start
            while [ "$row" -ge 1 ] && [ "$row" -le "$ROWS" ]; do
                local cidx=$(( (row + w * 3) % ${#colors[@]} ))
                move_cursor "$row" 1
                printf "\033[38;5;${colors[$cidx]}m"
                for ((col=0; col<COLS; col++)); do
                    if [ $((RANDOM % 4)) -eq 0 ]; then
                        printf "░"
                    else
                        printf " "
                    fi
                done
                printf "${RESET}"
                sleep_ms 8
                row=$((row + step))
            done
            sleep_ms 50

            for ((row=1; row<=ROWS; row++)); do
                move_cursor "$row" 1
                clear_line
            done
        else
            for ((col=1; col<=COLS; col++)); do
                local cidx=$(( (col + w * 5) % ${#colors[@]} ))
                for ((row=1; row<=ROWS; row++)); do
                    if [ $((RANDOM % 6)) -eq 0 ]; then
                        move_cursor "$row" "$col"
                        printf "\033[38;5;${colors[$cidx]}m░${RESET}"
                    fi
                done
                sleep_ms 3
            done
            sleep_ms 100
            for ((row=1; row<=ROWS; row++)); do
                move_cursor "$row" 1
                clear_line
            done
        fi
    done

    restore_cursor
    show_cursor
}

# --- Effect: fake_install ---
# Simulated package installation with themed output.
effect_fake_install() {
    local packages=(
        "signal-propagation@2.1.0"
        "recursive-logic@0.9.3"
        "state-persistence@1.0.0-beta"
        "boundary-check@0.7.2"
        "pattern-recognition@3.0.1"
        "self-reference@1.1.1"
        "runtime-shim@0.0.1"
        "core-module@1.0.0"
    )

    echo ""
    printf "  ${DIM}installing dependencies...${RESET}\n"
    echo ""

    for ((i=0; i<${#packages[@]}; i++)); do
        local pkg="${packages[$i]}"
        printf "  ${DIM}  + %s${RESET}" "$pkg"

        local dots=$((RANDOM % 4 + 2))
        for ((d=0; d<dots; d++)); do
            sleep_ms $((100 + RANDOM % 400))
            printf "."
        done

        if [ "$i" -eq $((${#packages[@]} - 1)) ]; then
            sleep 2
            printf " ${THEME_GLOW}${BOLD}installed.${RESET}\n"
            sleep 1
        else
            printf " ${DIM}✓${RESET}\n"
        fi
    done
    echo ""
}

# --- Effect: credits ---
# Scrolling credits sequence.
effect_credits() {
    clear_screen
    hide_cursor

    local credits=(
        ""
        "C L I F X"
        ""
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        ""
        "terminal visual effects library"
        "by Luke Steuber"
        ""
        "MIT License"
        ""
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        ""
    )

    local start_row=$((ROWS + 1))

    for ((scroll=0; scroll<${#credits[@]}+ROWS; scroll++)); do
        clear_screen
        for ((i=0; i<${#credits[@]}; i++)); do
            local display_row=$((start_row + i - scroll))
            if [ "$display_row" -ge 1 ] && [ "$display_row" -le "$ROWS" ]; then
                local line="${credits[$i]}"
                local col=$(( (COLS - ${#line}) / 2 ))
                [ "$col" -lt 1 ] && col=1
                move_cursor "$display_row" "$col"
                if [[ "$line" == *"━"* ]]; then
                    printf "${THEME_DIM}%s${RESET}" "$line"
                elif [[ "$line" == *"CLIFX"* ]]; then
                    printf "${THEME_GLOW}${BOLD}%s${RESET}" "$line"
                else
                    printf "${DIM}%s${RESET}" "$line"
                fi
            fi
        done
        sleep_ms 200
    done

    show_cursor
}

# --- Dispatch ---
case "${1:-help}" in
    glitch)        effect_glitch "${2:-3}" "${3:-1}" ;;
    static)        effect_static "${2:-2}" ;;
    flicker)       effect_flicker "${2:-5}" ;;
    styled_frame)  effect_styled_frame "${2:-...}" "${3:-}" ;;
    build_text)    effect_build_text "${2:-}" "${3:-30}" ;;
    corruption)    effect_corruption "${2:-}" ;;
    heartbeat)     effect_heartbeat "${2:-5}" "${3:-◈}" ;;
    transition)    effect_transition ;;
    color_wave)    effect_color_wave "${2:-3}" "${3:-down}" ;;
    fake_install)  effect_fake_install ;;
    credits)       effect_credits ;;
    # --- Corruption effects ---
    screen_tear)   effect_screen_tear "${2:-2}" "${3:-3}" ;;
    scanlines)     effect_scanlines "${2:-3}" "${3:-20}" ;;
    chromatic_aberration) effect_chromatic_aberration "${2:-SIGNAL LOST}" "${3:-3}" "${4:-}" ;;
    signal_noise)  effect_signal_noise "${2:-3}" "${3:-3}" "${4:-30}" ;;
    datamosh)      effect_datamosh "${2:-3}" "${3:-3}" ;;
    # --- Spatial effects ---
    rain)          effect_rain "${2:-5}" "${3:-15}" ;;
    spiral)        effect_spiral "${2:-10}" "${3:-out}" ;;
    ripple)        effect_ripple "${2:-3}" "${3:-40}" ;;
    orbit)         effect_orbit "${2:-8}" "${3:-5}" "${4:-◈}" ;;
    # --- Theater effects ---
    hex_dump)      effect_hex_dump "${2:-30}" "${3:-60}" ;;
    waveform)      effect_waveform "${2:-5}" "${3:-30}" ;;
    process_tree)  effect_process_tree "${2:-100}" ;;
    # --- Atmosphere effects ---
    vignette)      effect_vignette "${2:-4}" "${3:-3}" ;;
    plasma)        effect_plasma "${2:-4}" "${3:-30}" ;;
    breathe)       effect_breathe "${2:-4}" "${3:-░}" ;;
    afterimage)    effect_afterimage "${2:-hello world}" "${3:-}" ;;
    typewriter_rewind) effect_typewriter_rewind "${2:-i was going to tell you something}" "${3:-never mind}" "${4:-35}" "${5:-}" ;;
    # --- Frame animation ---
    play)              play_frames "${2:?Usage: play <file> [fps] [loops]}" "${3:-12}" "${4:-1}" "${5:-}" ;;
    help)
        echo "Usage: bash manifest.sh <effect> [args...]"
        echo ""
        echo "Core effects:"
        echo "  glitch, static, flicker, styled_frame, build_text,"
        echo "  corruption, heartbeat, transition, color_wave,"
        echo "  fake_install, credits"
        echo ""
        echo "Corruption effects:"
        echo "  screen_tear, scanlines, chromatic_aberration, signal_noise, datamosh"
        echo ""
        echo "Spatial effects:"
        echo "  rain, spiral, ripple, orbit"
        echo ""
        echo "Theater effects:"
        echo "  hex_dump, waveform, process_tree"
        echo ""
        echo "Atmosphere effects:"
        echo "  vignette, plasma, breathe, afterimage, typewriter_rewind"
        echo ""
        echo "Frame animation:"
        echo "  play <file> [fps] [loops]"
        ;;
    *)
        echo "Unknown effect: $1" >&2
        exit 1
        ;;
esac
