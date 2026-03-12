#!/usr/bin/env bash
# ============================================================================
# manifest_corruption.sh — Screen Corruption Effects
# Purpose: GPU artifacts, CRT distortion, signal interference
# Effects: screen_tear, scanlines, chromatic_aberration, signal_noise
# Sourced by manifest.sh — do not run directly
# ============================================================================

[[ -n "${_CLIFX_MANIFEST_CORRUPTION_LOADED:-}" ]] && return 0
_CLIFX_MANIFEST_CORRUPTION_LOADED=1

# --- Effect: screen_tear ---
# Horizontal displacement glitch. Rows briefly shift left/right with garbage,
# simulating GPU artifacts or VHS tracking errors.
effect_screen_tear() {
    local duration=${1:-2}
    local intensity=${2:-3}  # 1=subtle, 5=aggressive

    hide_cursor
    local end_time=$((SECONDS + duration))

    while [ $SECONDS -lt $end_time ]; do
        local bands=$((RANDOM % intensity + 1))
        local -a tear_rows=()

        for ((b=0; b<bands; b++)); do
            local row=$(random_int 1 "$ROWS")
            local offset=$(( (RANDOM % (intensity * 4 + 1)) - intensity * 2 ))
            [ $offset -eq 0 ] && offset=$((RANDOM % 2 * 2 - 1))
            tear_rows+=("$row")

            move_cursor "$row" 1
            local line=""
            local abs_offset=${offset#-}

            if [ $offset -gt 0 ]; then
                # Shift right: leading spaces + garbage
                for ((i=0; i<abs_offset && i<COLS; i++)); do
                    line+=" "
                done
                for ((i=0; i<COLS-abs_offset; i++)); do
                    if [ $((RANDOM % 2)) -eq 0 ]; then
                        line+="${FRAME_CHAR_SET[$((RANDOM % ${#FRAME_CHAR_SET[@]}))]}"
                    else
                        line+=" "
                    fi
                done
            else
                # Shift left: garbage, offset start
                for ((i=0; i<COLS-abs_offset; i++)); do
                    if [ $((RANDOM % 2)) -eq 0 ]; then
                        line+="${FRAME_CHAR_SET[$((RANDOM % ${#FRAME_CHAR_SET[@]}))]}"
                    else
                        line+=" "
                    fi
                done
            fi

            printf "${THEME_DIM}%s${RESET}" "$line"
        done

        sleep_ms $((40 / intensity))

        for row in "${tear_rows[@]}"; do
            move_cursor "$row" 1
            clear_line
        done

        sleep_ms $((20 / intensity))
    done
    show_cursor
}

# --- Effect: scanlines ---
# CRT monitor scanline effect. Alternating dim rows sweep down the screen
# with a faint green tint, like an old monitor warming up.
effect_scanlines() {
    local duration=${1:-3}
    local speed=${2:-20}  # ms per row

    hide_cursor
    local end_time=$((SECONDS + duration))
    local scanline_char="─"

    while [ $SECONDS -lt $end_time ]; do
        # Sweep scanlines down
        for ((row=1; row<=ROWS; row+=2)); do
            move_cursor "$row" 1
            printf "${THEME_DIM}"
            for ((col=0; col<COLS; col++)); do
                printf "%s" "$scanline_char"
            done
            printf "${RESET}"
            sleep_ms "$speed"
        done

        sleep_ms 100

        # Clear scanlines
        for ((row=1; row<=ROWS; row+=2)); do
            move_cursor "$row" 1
            clear_line
        done

        sleep_ms 200

        # Reverse sweep (odd rows)
        for ((row=ROWS; row>=1; row-=2)); do
            move_cursor "$row" 1
            printf "${THEME_DIM}"
            for ((col=0; col<COLS; col++)); do
                if [ $((RANDOM % 8)) -eq 0 ]; then
                    printf "${THEME_FG}%s${THEME_DIM}" "$scanline_char"
                else
                    printf "%s" "$scanline_char"
                fi
            done
            printf "${RESET}"
            sleep_ms "$speed"
        done

        sleep_ms 100

        for ((row=ROWS; row>=1; row-=2)); do
            move_cursor "$row" 1
            clear_line
        done

        sleep_ms 150
    done
    show_cursor
}

# --- Effect: chromatic_aberration ---
# RGB channel separation. Text appears in three offset color layers (red, green, blue)
# that jitter independently, creating a broken LCD / glitch aesthetic.
effect_chromatic_aberration() {
    local text="${1:-SIGNAL LOST}"
    local duration=${2:-3}
    local center_row=${3:-$((ROWS / 2))}
    local center_col=$(( (COLS - ${#text}) / 2 ))
    [ "$center_col" -lt 3 ] && center_col=3

    hide_cursor
    local end_time=$((SECONDS + duration))

    while [ $SECONDS -lt $end_time ]; do
        local r_offset=$((RANDOM % 3 - 1))  # -1, 0, or 1
        local b_offset=$((RANDOM % 3 - 1))

        # Clear area (3 rows to account for vertical offset)
        for ((dr=-1; dr<=1; dr++)); do
            local cr=$((center_row + dr))
            if [ "$cr" -ge 1 ] && [ "$cr" -le "$ROWS" ]; then
                move_cursor "$cr" 1
                clear_line
            fi
        done

        # Red layer (top, offset horizontally)
        local rr=$((center_row - 1))
        local rc=$((center_col + r_offset))
        [ "$rc" -lt 1 ] && rc=1
        if [ "$rr" -ge 1 ]; then
            move_cursor "$rr" "$rc"
            printf "\033[38;5;196m%s${RESET}" "$text"
        fi

        # Green layer (center — the "true" position)
        move_cursor "$center_row" "$center_col"
        printf "${THEME_GLOW}%s${RESET}" "$text"

        # Blue layer (bottom, offset horizontally)
        local br=$((center_row + 1))
        local bc=$((center_col + b_offset))
        [ "$bc" -lt 1 ] && bc=1
        if [ "$br" -le "$ROWS" ]; then
            move_cursor "$br" "$bc"
            printf "\033[38;5;63m%s${RESET}" "$text"
        fi

        sleep_ms 80
    done

    # Clean up
    for ((dr=-1; dr<=1; dr++)); do
        local cr=$((center_row + dr))
        if [ "$cr" -ge 1 ] && [ "$cr" -le "$ROWS" ]; then
            move_cursor "$cr" 1
            clear_line
        fi
    done
    show_cursor
}

# --- Effect: signal_noise ---
# Horizontal bands of interference scroll across the screen, overlaying
# and restoring content. Like a bad antenna or jammed signal.
effect_signal_noise() {
    local duration=${1:-3}
    local band_height=${2:-3}
    local speed=${3:-30}

    hide_cursor
    local end_time=$((SECONDS + duration))

    while [ $SECONDS -lt $end_time ]; do
        local band_start=$(random_int 1 "$((ROWS - band_height))")

        # Draw noise band
        for ((row=band_start; row<band_start+band_height && row<=ROWS; row++)); do
            move_cursor "$row" 1
            local line=""
            for ((col=0; col<COLS; col++)); do
                case $((RANDOM % 5)) in
                    0) line+="${FRAME_CHAR_SET[$((RANDOM % ${#FRAME_CHAR_SET[@]}))]}" ;;
                    1) line+="░" ;;
                    2) line+="▒" ;;
                    *) line+=" " ;;
                esac
            done
            printf "${THEME_DIM}%s${RESET}" "$line"
        done

        sleep_ms "$speed"

        # Clear noise band
        for ((row=band_start; row<band_start+band_height && row<=ROWS; row++)); do
            move_cursor "$row" 1
            clear_line
        done

        # Scroll direction: band moves down
        band_start=$((band_start + 1))
        if [ "$band_start" -gt "$ROWS" ]; then
            band_start=1
        fi

        sleep_ms "$speed"
    done
    show_cursor
}

# --- Effect: datamosh ---
# Blocks of the screen swap positions briefly, like a corrupted video codec.
# Rectangular regions jump to wrong locations, hold, then snap back.
effect_datamosh() {
    local duration=${1:-3}
    local intensity=${2:-3}  # number of swapped blocks per frame

    hide_cursor
    local end_time=$((SECONDS + duration))

    while [ $SECONDS -lt $end_time ]; do
        local -a block_rows=()
        local -a block_cols=()
        local -a block_widths=()
        local -a block_heights=()

        for ((b=0; b<intensity; b++)); do
            local bw=$((RANDOM % 15 + 5))
            local bh=$((RANDOM % 3 + 1))
            local src_row=$(random_int 1 "$((ROWS - bh))")
            local src_col=$(random_int 1 "$((COLS - bw))")
            local dst_row=$(random_int 1 "$((ROWS - bh))")
            local dst_col=$(random_int 1 "$((COLS - bw))")

            block_rows+=("$dst_row")
            block_cols+=("$dst_col")
            block_widths+=("$bw")
            block_heights+=("$bh")

            # Draw a block of garbage at the destination
            for ((r=0; r<bh; r++)); do
                local row=$((dst_row + r))
                [ "$row" -gt "$ROWS" ] && continue
                move_cursor "$row" "$dst_col"
                local line=""
                for ((c=0; c<bw; c++)); do
                    if [ $((RANDOM % 3)) -eq 0 ]; then
                        line+="${FRAME_CHAR_SET[$((RANDOM % ${#FRAME_CHAR_SET[@]}))]}"
                    elif [ $((RANDOM % 2)) -eq 0 ]; then
                        line+="▓"
                    else
                        line+="░"
                    fi
                done
                printf "${THEME_ACCENT}%s${RESET}" "$line"
            done
        done

        sleep_ms $((60 / intensity + 20))

        # Clear the blocks
        for ((b=0; b<${#block_rows[@]}; b++)); do
            local bh=${block_heights[$b]}
            local bw=${block_widths[$b]}
            for ((r=0; r<bh; r++)); do
                local row=$((${block_rows[$b]} + r))
                [ "$row" -gt "$ROWS" ] && continue
                move_cursor "$row" "${block_cols[$b]}"
                printf "%*s" "$bw" ""
            done
        done

        sleep_ms $((30 / intensity + 10))
    done
    show_cursor
}
