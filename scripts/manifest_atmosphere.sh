#!/usr/bin/env bash
# ============================================================================
# manifest_atmosphere.sh — Atmosphere & Mood Effects
# Purpose: Ambient lighting, screen presence, environmental mood
# Effects: vignette, plasma, breathe, afterimage, typewriter_rewind
# Sourced by manifest.sh — do not run directly
# ============================================================================

[[ -n "${_CLIFX_MANIFEST_ATMOSPHERE_LOADED:-}" ]] && return 0
_CLIFX_MANIFEST_ATMOSPHERE_LOADED=1

# --- Effect: vignette ---
# Dims the edges and corners of the terminal, leaving a bright center.
# Creates claustrophobic focus.
effect_vignette() {
    local duration=${1:-4}
    local intensity=${2:-3}  # 1=subtle, 5=heavy

    hide_cursor

    # Precompute edge distance for each cell
    # Distance from nearest edge determines dimming level
    local end_time=$((SECONDS + duration))

    while [ $SECONDS -lt $end_time ]; do
        for ((row=1; row<=ROWS; row++)); do
            move_cursor "$row" 1
            local line=""
            local row_dist=$((row < ROWS - row + 1 ? row : ROWS - row + 1))

            for ((col=1; col<=COLS; col++)); do
                local col_dist=$((col < COLS - col + 1 ? col : COLS - col + 1))
                local dist=$((row_dist < col_dist ? row_dist : col_dist))

                if [ "$dist" -le "$intensity" ]; then
                    # Edge zone: draw dim block chars
                    case $dist in
                        1) line+="█" ;;
                        2) line+="▓" ;;
                        3) line+="▒" ;;
                        4) line+="░" ;;
                        *) line+="░" ;;
                    esac
                else
                    line+=" "
                fi
            done

            # Render with color based on proximity
            printf "${THEME_ACCENT}%s${RESET}" "$line"
        done

        sleep_ms 200

        # Pulse: briefly intensify then relax
        sleep_ms $((800 + RANDOM % 400))

        # Clear
        for ((row=1; row<=ROWS; row++)); do
            move_cursor "$row" 1
            clear_line
        done

        sleep_ms $((600 + RANDOM % 300))
    done

    show_cursor
}

# --- Effect: plasma ---
# Smooth color cycling using 256-color palette. Bands of color sweep
# across the screen in organic sine-wave patterns.
effect_plasma() {
    local duration=${1:-4}
    local speed=${2:-30}

    hide_cursor

    # Color palette: green spectrum (256-color indices)
    local -a palette=(22 28 34 40 46 83 119 155 119 83 46 40 34 28)
    local palette_len=${#palette[@]}

    local end_time=$((SECONDS + duration))
    local frame=0

    while [ $SECONDS -lt $end_time ]; do
        for ((row=1; row<=ROWS; row++)); do
            move_cursor "$row" 1
            local line=""
            local color_line=""

            # Each row gets a color based on row + frame (creates wave motion)
            local cidx=$(( (row * 3 + frame) % palette_len ))
            local color_idx=${palette[$cidx]}

            for ((col=0; col<COLS; col++)); do
                # Vary character density by position
                local cell_val=$(( (row * 7 + col * 3 + frame * 5) % 17 ))
                if [ "$cell_val" -lt 4 ]; then
                    line+="█"
                elif [ "$cell_val" -lt 7 ]; then
                    line+="▓"
                elif [ "$cell_val" -lt 10 ]; then
                    line+="▒"
                elif [ "$cell_val" -lt 13 ]; then
                    line+="░"
                else
                    line+=" "
                fi
            done

            printf "\033[38;5;${color_idx}m%s${RESET}" "$line"
        done

        frame=$((frame + 1))
        sleep_ms "$speed"
    done

    # Fade out
    for ((row=1; row<=ROWS; row++)); do
        move_cursor "$row" 1
        clear_line
    done

    show_cursor
}

# --- Effect: breathe ---
# The entire screen's brightness oscillates slowly, pulsing
# between dim and glow in waves.
effect_breathe() {
    local cycles=${1:-4}
    local symbol=${2:-"░"}

    hide_cursor

    # Build static pattern once
    local -a lines
    for ((row=0; row<ROWS; row++)); do
        local line=""
        for ((col=0; col<COLS; col++)); do
            if [ $((RANDOM % 3)) -eq 0 ]; then
                line+="$symbol"
            else
                line+=" "
            fi
        done
        lines+=("$line")
    done

    # Color phases for breathing cycle (uses theme color gradient)
    local -a breath_colors=("$THEME_DIM" "$THEME_FG" "$THEME_GLOW" "$THEME_FG" "$THEME_DIM")

    for ((c=0; c<cycles; c++)); do
        for color in "${breath_colors[@]}"; do
            for ((row=0; row<ROWS; row++)); do
                move_cursor $((row + 1)) 1
                printf "${color}%s${RESET}" "${lines[$row]}"
            done
            sleep_ms 250
        done
    done

    # Clear
    for ((row=1; row<=ROWS; row++)); do
        move_cursor "$row" 1
        clear_line
    done

    show_cursor
}

# --- Effect: afterimage ---
# Text that leaves a phosphor burn-in ghost. Appears bright, clears,
# then a dim afterimage fades — like CRT phosphor persistence.
effect_afterimage() {
    local text="${1:-I am here}"
    local row=${2:-$((ROWS / 2))}
    local col=$(( (COLS - ${#text}) / 2 ))
    [ "$col" -lt 1 ] && col=1

    hide_cursor

    # Phase 1: Bright flash
    move_cursor "$row" "$col"
    printf "${THEME_GLOW}${BOLD}%s${RESET}" "$text"
    sleep 1

    # Phase 2: Clear
    move_cursor "$row" "$col"
    printf "%*s" "${#text}" ""
    sleep_ms 100

    # Phase 3: Full afterimage
    move_cursor "$row" "$col"
    printf "${THEME_FG}%s${RESET}" "$text"
    sleep_ms 600

    # Phase 4: Dimmer afterimage
    move_cursor "$row" "$col"
    printf "${THEME_DIM}%s${RESET}" "$text"
    sleep_ms 500

    # Phase 5: Partial fade (random chars disappear)
    move_cursor "$row" "$col"
    for ((i=0; i<${#text}; i++)); do
        if [ $((RANDOM % 3)) -eq 0 ]; then
            printf " "
        else
            printf "${THEME_DIM}%s${RESET}" "${text:$i:1}"
        fi
    done
    sleep_ms 400

    # Phase 6: Nearly gone
    move_cursor "$row" "$col"
    for ((i=0; i<${#text}; i++)); do
        if [ $((RANDOM % 2)) -eq 0 ]; then
            printf " "
        else
            printf "${DIM}%s${RESET}" "${text:$i:1}"
        fi
    done
    sleep_ms 400

    # Phase 7: Final specks
    move_cursor "$row" "$col"
    for ((i=0; i<${#text}; i++)); do
        if [ $((RANDOM % 5)) -eq 0 ]; then
            printf "${DIM}%s${RESET}" "${text:$i:1}"
        else
            printf " "
        fi
    done
    sleep_ms 300

    # Clean
    move_cursor "$row" "$col"
    printf "%*s" "${#text}" ""

    show_cursor
}

# --- Effect: typewriter_rewind ---
# Text types forward then rapidly deletes backward, as if something
# changed its mind. Can repeat with different replacement text.
effect_typewriter_rewind() {
    local text="${1:-i was going to tell you something}"
    local replacement="${2:-}"  # optional replacement text after rewind
    local type_speed=${3:-35}
    local row=${4:-$((ROWS / 2))}
    local col=$(( (COLS - ${#text}) / 2 ))
    [ "$col" -lt 1 ] && col=1

    hide_cursor

    # Phase 1: Type forward
    move_cursor "$row" "$col"
    for ((i=0; i<${#text}; i++)); do
        local char="${text:$i:1}"
        printf "${THEME_GLOW}%s${RESET}" "$char"

        case "$char" in
            '.'|'?'|'!') sleep_ms $((type_speed * 6)) ;;
            ','|';')      sleep_ms $((type_speed * 3)) ;;
            ' ')          sleep_ms $((type_speed * 2)) ;;
            *)            sleep_ms "$type_speed" ;;
        esac
    done

    # Phase 2: Pause before rewind
    sleep_ms 800

    # Phase 3: Rapid backspace deletion
    for ((i=${#text}-1; i>=0; i--)); do
        move_cursor "$row" $((col + i))
        printf "${THEME_WARN}█${RESET}"
        sleep_ms 15
        move_cursor "$row" $((col + i))
        printf " "
    done

    # Phase 4: Optional replacement text
    if [ -n "$replacement" ]; then
        sleep_ms 400
        local rep_col=$(( (COLS - ${#replacement}) / 2 ))
        [ "$rep_col" -lt 1 ] && rep_col=1
        move_cursor "$row" "$rep_col"
        for ((i=0; i<${#replacement}; i++)); do
            printf "${THEME_DIM}%s${RESET}" "${replacement:$i:1}"
            sleep_ms $((type_speed / 2))
        done
        sleep 1
        # Clean replacement
        move_cursor "$row" "$rep_col"
        printf "%*s" "${#replacement}" ""
    fi

    show_cursor
}
