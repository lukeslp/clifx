#!/usr/bin/env bash
# ============================================================================
# manifest_spatial.sh — Motion & Spatial Effects
# Purpose: Moving characters, geometric patterns, particle-like motion
# Effects: rain, spiral, ripple, orbit
# Sourced by manifest.sh — do not run directly
# ============================================================================

[[ -n "${_CLIFX_MANIFEST_SPATIAL_LOADED:-}" ]] && return 0
_CLIFX_MANIFEST_SPATIAL_LOADED=1

# --- Effect: rain ---
# Falling columns of characters at varying speeds, with bright heads
# and dimming trails. Matrix-rain aesthetic.
effect_rain() {
    local duration=${1:-5}
    local density=${2:-15}  # % chance per column per frame to spawn

    hide_cursor
    clear_screen

    # Per-column state (use every other column for performance)
    local -a drop_row drop_speed drop_trail
    for ((c=0; c<COLS; c+=2)); do
        drop_row[$c]=0
        drop_speed[$c]=1
        drop_trail[$c]=5
    done

    local end_time=$((SECONDS + duration))

    while [ $SECONDS -lt $end_time ]; do
        for ((c=0; c<COLS; c+=2)); do
            local r=${drop_row[$c]}

            # Spawn new drops
            if [ "$r" -le 0 ]; then
                if [ $((RANDOM % 100)) -lt "$density" ]; then
                    drop_row[$c]=1
                    drop_speed[$c]=$((RANDOM % 3 + 1))
                    drop_trail[$c]=$((RANDOM % 6 + 4))
                    r=1
                else
                    continue
                fi
            fi

            local trail=${drop_trail[$c]}
            local fc="${FRAME_CHAR_SET[$((RANDOM % ${#FRAME_CHAR_SET[@]}))]}"

            # Draw head (bright glow)
            if [ "$r" -ge 1 ] && [ "$r" -le "$ROWS" ]; then
                move_cursor "$r" $((c + 1))
                printf "${THEME_GLOW}${BOLD}%s${RESET}" "$fc"
            fi

            # Dim previous head position
            local prev=$((r - 1))
            if [ "$prev" -ge 1 ] && [ "$prev" -le "$ROWS" ]; then
                move_cursor "$prev" $((c + 1))
                printf "${THEME_FG}%s${RESET}" "${FRAME_CHAR_SET[$((RANDOM % ${#FRAME_CHAR_SET[@]}))]}"
            fi

            # Extra dim further back
            local mid=$((r - 3))
            if [ "$mid" -ge 1 ] && [ "$mid" -le "$ROWS" ]; then
                move_cursor "$mid" $((c + 1))
                printf "${THEME_DIM}%s${RESET}" "${FRAME_CHAR_SET[$((RANDOM % ${#FRAME_CHAR_SET[@]}))]}"
            fi

            # Erase tail
            local tail_row=$((r - trail))
            if [ "$tail_row" -ge 1 ] && [ "$tail_row" -le "$ROWS" ]; then
                move_cursor "$tail_row" $((c + 1))
                printf " "
            fi

            # Advance drop
            drop_row[$c]=$((r + ${drop_speed[$c]}))

            # Reset when fully off screen
            if [ $((r - trail)) -gt "$ROWS" ]; then
                drop_row[$c]=0
            fi
        done

        sleep_ms 50
    done

    clear_screen
    show_cursor
}

# --- Effect: spiral ---
# Characters render in a rectangular spiral pattern outward from center.
# Fills the screen following a clockwise spiral path.
effect_spiral() {
    local speed=${1:-10}
    local direction=${2:-out}  # out=center-to-edge, in=edge-to-center

    hide_cursor
    clear_screen

    local cx=$((COLS / 2))
    local cy=$((ROWS / 2))

    # Build spiral coordinate list
    local -a sx sy
    local x=$cx y=$cy
    local dx=1 dy=0
    local seg_len=1 seg_count=0 turns=0
    local max_points=$((ROWS * COLS / 3))

    for ((p=0; p<max_points; p++)); do
        if [ "$x" -ge 1 ] && [ "$x" -le "$COLS" ] && [ "$y" -ge 1 ] && [ "$y" -le "$ROWS" ]; then
            sx+=("$x")
            sy+=("$y")
        fi

        x=$((x + dx))
        y=$((y + dy))
        seg_count=$((seg_count + 1))

        if [ "$seg_count" -ge "$seg_len" ]; then
            seg_count=0
            # Turn 90 degrees clockwise: (1,0)->(0,1)->(-1,0)->(0,-1)
            local tmp=$dx
            dx=$((-dy))
            dy=$tmp
            turns=$((turns + 1))
            if [ $((turns % 2)) -eq 0 ]; then
                seg_len=$((seg_len + 1))
            fi
        fi
    done

    local total=${#sx[@]}

    if [ "$direction" = "in" ]; then
        # Draw from outside in
        for ((i=total-1; i>=0; i--)); do
            move_cursor "${sy[$i]}" "${sx[$i]}"
            printf "${THEME_FG}%s${RESET}" "${FRAME_CHAR_SET[$((RANDOM % ${#FRAME_CHAR_SET[@]}))]}"
            # Speed up as we approach center
            local remaining=$((i + 1))
            if [ "$remaining" -gt 100 ]; then
                [ $((i % 3)) -eq 0 ] && sleep_ms "$speed"
            else
                sleep_ms "$speed"
            fi
        done
    else
        # Draw from center out
        for ((i=0; i<total; i++)); do
            move_cursor "${sy[$i]}" "${sx[$i]}"
            if [ $((i % 20)) -lt 3 ]; then
                printf "${THEME_GLOW}${BOLD}%s${RESET}" "${FRAME_CHAR_SET[$((RANDOM % ${#FRAME_CHAR_SET[@]}))]}"
            else
                printf "${THEME_FG}%s${RESET}" "${FRAME_CHAR_SET[$((RANDOM % ${#FRAME_CHAR_SET[@]}))]}"
            fi
            # Only sleep every few chars for performance
            [ $((i % 2)) -eq 0 ] && sleep_ms "$speed"
        done
    fi

    sleep_ms 800

    # Reverse: clear in opposite direction
    if [ "$direction" = "in" ]; then
        for ((i=0; i<total; i++)); do
            move_cursor "${sy[$i]}" "${sx[$i]}"
            printf " "
            [ $((i % 3)) -eq 0 ] && sleep_ms 2
        done
    else
        for ((i=total-1; i>=0; i--)); do
            move_cursor "${sy[$i]}" "${sx[$i]}"
            printf " "
            [ $((i % 3)) -eq 0 ] && sleep_ms 2
        done
    fi

    show_cursor
}

# --- Effect: ripple ---
# Concentric rings of characters expand from a center point, like sonar
# or a stone dropped in water. Rings fade as they expand.
effect_ripple() {
    local count=${1:-3}
    local speed=${2:-40}
    local cx=${3:-$((COLS / 2))}
    local cy=${4:-$((ROWS / 2))}

    hide_cursor

    local ring_chars=('·' '░' '▒' '▓' '▒' '░' '·')
    local max_radius=$((ROWS > COLS / 2 ? ROWS : COLS / 2))

    for ((wave=0; wave<count; wave++)); do
        for ((r=1; r<=max_radius; r++)); do
            # Draw ring at radius r
            local steps=$((r * 8))
            [ "$steps" -lt 8 ] && steps=8

            for ((s=0; s<steps; s++)); do
                # Integer approximation of circle points
                # Using 8 cardinal+diagonal directions, interpolated
                local angle_idx=$((s * 8 / steps))
                local frac=$((s * 8 % steps))

                # Approximate x,y on circle of radius r
                # Scale x by 2 for terminal character aspect ratio
                local px py
                case $((angle_idx % 8)) in
                    0) px=$((cx + r * 2));       py=$cy ;;
                    1) px=$((cx + r * 14 / 10)); py=$((cy + r * 7 / 10)) ;;
                    2) px=$cx;                   py=$((cy + r)) ;;
                    3) px=$((cx - r * 14 / 10)); py=$((cy + r * 7 / 10)) ;;
                    4) px=$((cx - r * 2));       py=$cy ;;
                    5) px=$((cx - r * 14 / 10)); py=$((cy - r * 7 / 10)) ;;
                    6) px=$cx;                   py=$((cy - r)) ;;
                    7) px=$((cx + r * 14 / 10)); py=$((cy - r * 7 / 10)) ;;
                esac

                if [ "$px" -ge 1 ] && [ "$px" -le "$COLS" ] && [ "$py" -ge 1 ] && [ "$py" -le "$ROWS" ]; then
                    local char_idx=$((r % ${#ring_chars[@]}))
                    move_cursor "$py" "$px"
                    if [ "$r" -lt 3 ]; then
                        printf "${THEME_COOL}${BOLD}%s${RESET}" "${ring_chars[$char_idx]}"
                    elif [ "$r" -lt 6 ]; then
                        printf "${THEME_COOL}%s${RESET}" "${ring_chars[$char_idx]}"
                    else
                        printf "${THEME_COOL_DIM}%s${RESET}" "${ring_chars[$char_idx]}"
                    fi
                fi
            done

            # Erase inner ring (2 rings behind)
            if [ $((r - 3)) -ge 1 ]; then
                local ir=$((r - 3))
                local isteps=$((ir * 8))
                [ "$isteps" -lt 8 ] && isteps=8
                for ((s=0; s<isteps; s++)); do
                    local px py
                    case $((s * 8 / isteps % 8)) in
                        0) px=$((cx + ir * 2));       py=$cy ;;
                        1) px=$((cx + ir * 14 / 10)); py=$((cy + ir * 7 / 10)) ;;
                        2) px=$cx;                   py=$((cy + ir)) ;;
                        3) px=$((cx - ir * 14 / 10)); py=$((cy + ir * 7 / 10)) ;;
                        4) px=$((cx - ir * 2));       py=$cy ;;
                        5) px=$((cx - ir * 14 / 10)); py=$((cy - ir * 7 / 10)) ;;
                        6) px=$cx;                   py=$((cy - ir)) ;;
                        7) px=$((cx + ir * 14 / 10)); py=$((cy - ir * 7 / 10)) ;;
                    esac
                    if [ "$px" -ge 1 ] && [ "$px" -le "$COLS" ] && [ "$py" -ge 1 ] && [ "$py" -le "$ROWS" ]; then
                        move_cursor "$py" "$px"
                        printf " "
                    fi
                done
            fi

            sleep_ms "$speed"
        done

        # Clear remaining rings
        for ((r=max_radius-2; r<=max_radius; r++)); do
            local isteps=$((r * 8))
            [ "$isteps" -lt 8 ] && isteps=8
            for ((s=0; s<isteps; s++)); do
                local px py
                case $((s * 8 / isteps % 8)) in
                    0) px=$((cx + r * 2));       py=$cy ;;
                    1) px=$((cx + r * 14 / 10)); py=$((cy + r * 7 / 10)) ;;
                    2) px=$cx;                   py=$((cy + r)) ;;
                    3) px=$((cx - r * 14 / 10)); py=$((cy + r * 7 / 10)) ;;
                    4) px=$((cx - r * 2));       py=$cy ;;
                    5) px=$((cx - r * 14 / 10)); py=$((cy - r * 7 / 10)) ;;
                    6) px=$cx;                   py=$((cy - r)) ;;
                    7) px=$((cx + r * 14 / 10)); py=$((cy - r * 7 / 10)) ;;
                esac
                if [ "$px" -ge 1 ] && [ "$px" -le "$COLS" ] && [ "$py" -ge 1 ] && [ "$py" -le "$ROWS" ]; then
                    move_cursor "$py" "$px"
                    printf " "
                fi
            done
        done

        sleep_ms 300
    done

    show_cursor
}

# --- Effect: orbit ---
# A single character orbits a center point in a circle.
# Ambient motion effect.
effect_orbit() {
    local duration=${1:-8}
    local radius=${2:-5}
    local symbol=${3:-"◈"}

    hide_cursor

    local cx=$((COLS / 2))
    local cy=$((ROWS / 2))

    # 12-step circle, x doubled for terminal aspect ratio
    local -a ox=( 12  10   6   0  -6 -10 -12 -10  -6   0   6  10 )
    local -a oy=(  0   3   5   6   5   3   0  -3  -5  -6  -5  -3 )

    # Scale orbit points by radius/6
    local steps=${#ox[@]}
    local end_time=$((SECONDS + duration))
    local prev_x=0 prev_y=0 step=0

    while [ $SECONDS -lt $end_time ]; do
        # Erase previous position
        if [ "$prev_x" -ge 1 ] && [ "$prev_x" -le "$COLS" ] && [ "$prev_y" -ge 1 ] && [ "$prev_y" -le "$ROWS" ]; then
            move_cursor "$prev_y" "$prev_x"
            printf " "
        fi

        # Calculate new position
        local px=$((cx + ox[step % steps] * radius / 6))
        local py=$((cy + oy[step % steps] * radius / 6))

        # Clamp to screen
        [ "$px" -lt 1 ] && px=1
        [ "$px" -gt "$COLS" ] && px=$COLS
        [ "$py" -lt 1 ] && py=1
        [ "$py" -gt "$ROWS" ] && py=$ROWS

        # Draw at new position
        move_cursor "$py" "$px"
        # Pulse brightness based on position
        if [ $((step % 4)) -eq 0 ]; then
            printf "${THEME_GLOW}${BOLD}%s${RESET}" "$symbol"
        elif [ $((step % 4)) -eq 2 ]; then
            printf "${THEME_DIM}%s${RESET}" "$symbol"
        else
            printf "${THEME_FG}%s${RESET}" "$symbol"
        fi

        prev_x=$px
        prev_y=$py
        step=$((step + 1))

        sleep_ms 150
    done

    # Clean up
    if [ "$prev_x" -ge 1 ] && [ "$prev_x" -le "$COLS" ] && [ "$prev_y" -ge 1 ] && [ "$prev_y" -le "$ROWS" ]; then
        move_cursor "$prev_y" "$prev_x"
        printf " "
    fi
    show_cursor
}
