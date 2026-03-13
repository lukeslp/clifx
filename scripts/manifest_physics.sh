#!/usr/bin/env bash
# ============================================================================
# manifest_physics.sh — Physics-Based Terminal Effects
#
# Purpose: Simulate physical phenomena — particle systems, gravity, springs,
#          and fluid dynamics — using ASCII characters and ANSI color.
#
# Effects:
#   effect_particles       — Burst of particles with velocity and gravity
#   effect_gravity_text    — Text that falls, bounces, and settles
#   effect_explosion       — Radial burst from a center point
#   effect_fountain        — Continuous upward particle fountain
#   effect_shockwave       — Expanding ring shockwave from center
#
# Sourced by manifest.sh — do not run directly.
# ============================================================================

[[ -n "${_CLIFX_MANIFEST_PHYSICS_LOADED:-}" ]] && return 0
_CLIFX_MANIFEST_PHYSICS_LOADED=1

# ---------------------------------------------------------------------------
# Internal: physics particle state
# Each particle: "x y vx vy char color age"
# Stored as parallel arrays for Bash performance.
# ---------------------------------------------------------------------------

# Gravity constant (pixels per frame squared, scaled by 10 for integer math)
_PHYS_GRAVITY=2

# ---------------------------------------------------------------------------
# effect_particles — Burst particle system
#
# Usage: effect_particles [duration] [count] [origin_x] [origin_y]
#   duration: seconds (default: 3)
#   count:    number of particles (default: 20)
#   origin_x: x origin (default: center)
#   origin_y: y origin (default: center)
# ---------------------------------------------------------------------------
effect_particles() {
    local duration=${1:-3}
    local count=${2:-20}
    local ox=${3:-$(( TERM_COLS / 2 ))}
    local oy=${4:-$(( TERM_ROWS / 2 ))}

    hide_cursor

    # Particle state arrays (integer math, values * 10 for sub-cell precision)
    local -a px py pvx pvy page pchar pcolor

    # Particle character sets
    local chars=('·' '•' '◦' '○' '◉' '✦' '✧' '★' '✸' '✹' '✺' '⊹' '⊛')
    local colors=("$THEME_FG" "$THEME_GLOW" "$THEME_ACCENT" "$THEME_COOL" "$THEME_HOT" "$THEME_ELECTRIC")

    # Initialize particles
    for (( i=0; i<count; i++ )); do
        px[i]=$(( ox * 10 ))
        py[i]=$(( oy * 10 ))
        # Random velocity: vx in [-15,15], vy in [-20,-5] (upward bias)
        pvx[i]=$(( (RANDOM % 31) - 15 ))
        pvy[i]=$(( -((RANDOM % 16) + 5) ))
        page[i]=0
        pchar[i]="${chars[$((RANDOM % ${#chars[@]}))]}"
        pcolor[i]="${colors[$((RANDOM % ${#colors[@]}))]}"
    done

    local end_time=$(( SECONDS + duration ))
    local -a prev_x prev_y
    for (( i=0; i<count; i++ )); do prev_x[i]=-1; prev_y[i]=-1; done

    while [[ $SECONDS -lt $end_time ]]; do
        for (( i=0; i<count; i++ )); do
            # Erase previous position
            local ppx=${prev_x[i]} ppy=${prev_y[i]}
            if [[ $ppx -ge 1 && $ppx -le $TERM_COLS && $ppy -ge 1 && $ppy -le $TERM_ROWS ]]; then
                move_cursor "$ppy" "$ppx"
                printf " "
            fi

            # Update physics
            pvy[i]=$(( pvy[i] + _PHYS_GRAVITY ))
            px[i]=$(( px[i] + pvx[i] ))
            py[i]=$(( py[i] + pvy[i] ))
            page[i]=$(( page[i] + 1 ))

            # Bounce off floor
            local floor=$(( TERM_ROWS * 10 ))
            if [[ ${py[i]} -ge $floor ]]; then
                py[i]=$floor
                pvy[i]=$(( -(pvy[i] * 6 / 10) ))  # 60% energy retention
                # Dampen horizontal velocity
                pvx[i]=$(( pvx[i] * 8 / 10 ))
            fi

            # Bounce off walls
            if [[ ${px[i]} -lt 10 ]]; then
                px[i]=10
                pvx[i]=$(( -pvx[i] * 7 / 10 ))
            elif [[ ${px[i]} -gt $(( TERM_COLS * 10 )) ]]; then
                px[i]=$(( TERM_COLS * 10 ))
                pvx[i]=$(( -pvx[i] * 7 / 10 ))
            fi

            # Render
            local cx=$(( px[i] / 10 ))
            local cy=$(( py[i] / 10 ))

            # Fade color with age
            local age=${page[i]}
            local color="${pcolor[i]}"
            if [[ $age -gt 20 ]]; then color="$THEME_DIM"; fi
            if [[ $age -gt 35 ]]; then color="$UI_DIM"; fi

            if [[ $cx -ge 1 && $cx -le $TERM_COLS && $cy -ge 1 && $cy -le $TERM_ROWS ]]; then
                move_cursor "$cy" "$cx"
                printf "%b%s%b" "$color" "${pchar[i]}" "$RESET"
                prev_x[i]=$cx
                prev_y[i]=$cy
            fi
        done

        sleep_ms 40
    done

    # Erase all particles
    for (( i=0; i<count; i++ )); do
        local ppx=${prev_x[i]} ppy=${prev_y[i]}
        if [[ $ppx -ge 1 && $ppx -le $TERM_COLS && $ppy -ge 1 && $ppy -le $TERM_ROWS ]]; then
            move_cursor "$ppy" "$ppx"
            printf " "
        fi
    done

    show_cursor
}

# ---------------------------------------------------------------------------
# effect_gravity_text — Text that falls, bounces, and settles
#
# Usage: effect_gravity_text [text] [duration]
# ---------------------------------------------------------------------------
effect_gravity_text() {
    local text="${1:-CLIFX}"
    local duration=${2:-4}

    hide_cursor

    local text_len=${#text}
    local start_x=$(( (TERM_COLS - text_len) / 2 ))
    local floor_y=$(( TERM_ROWS - 2 ))

    # Each character is an independent particle
    local -a cx cy cvx cvy cage
    for (( i=0; i<text_len; i++ )); do
        cx[i]=$(( (start_x + i) * 10 ))
        cy[i]=$(( 1 * 10 ))
        cvx[i]=$(( (RANDOM % 5) - 2 ))
        cvy[i]=$(( RANDOM % 5 + 1 ))
        cage[i]=0
    done

    local -a prev_cx prev_cy
    for (( i=0; i<text_len; i++ )); do prev_cx[i]=-1; prev_cy[i]=-1; done

    local end_time=$(( SECONDS + duration ))
    local all_settled=0

    while [[ $SECONDS -lt $end_time && $all_settled -eq 0 ]]; do
        all_settled=1

        for (( i=0; i<text_len; i++ )); do
            # Erase previous
            local ppx=${prev_cx[i]} ppy=${prev_cy[i]}
            if [[ $ppx -ge 1 && $ppx -le $TERM_COLS && $ppy -ge 1 && $ppy -le $TERM_ROWS ]]; then
                move_cursor "$ppy" "$ppx"
                printf " "
            fi

            # Apply gravity
            cvy[i]=$(( cvy[i] + _PHYS_GRAVITY ))
            cx[i]=$(( cx[i] + cvx[i] ))
            cy[i]=$(( cy[i] + cvy[i] ))
            cage[i]=$(( cage[i] + 1 ))

            # Floor bounce
            local floor=$(( floor_y * 10 ))
            if [[ ${cy[i]} -ge $floor ]]; then
                cy[i]=$floor
                cvy[i]=$(( -(cvy[i] * 5 / 10) ))
                cvx[i]=$(( cvx[i] * 9 / 10 ))
                # Stop bouncing when velocity is tiny
                if [[ ${cvy[i]} -gt -3 && ${cvy[i]} -lt 3 ]]; then
                    cvy[i]=0
                fi
            fi

            # Wall bounce
            local left_wall=$(( start_x * 10 - 20 ))
            local right_wall=$(( (start_x + text_len + 2) * 10 ))
            if [[ ${cx[i]} -lt $left_wall ]]; then
                cx[i]=$left_wall; cvx[i]=$(( -cvx[i] ))
            elif [[ ${cx[i]} -gt $right_wall ]]; then
                cx[i]=$right_wall; cvx[i]=$(( -cvx[i] ))
            fi

            # Check if still moving
            if [[ ${cvy[i]} -ne 0 || ${cvx[i]} -ne 0 ]]; then
                all_settled=0
            fi

            # Render character
            local rcx=$(( cx[i] / 10 ))
            local rcy=$(( cy[i] / 10 ))

            local char="${text:$i:1}"
            local age=${cage[i]}
            local color="$THEME_GLOW"
            if [[ $age -gt 10 ]]; then color="$THEME_FG"; fi
            if [[ ${cvy[i]} -eq 0 && ${cvx[i]} -eq 0 ]]; then color="$THEME_ACCENT"; fi

            if [[ $rcx -ge 1 && $rcx -le $TERM_COLS && $rcy -ge 1 && $rcy -le $TERM_ROWS ]]; then
                move_cursor "$rcy" "$rcx"
                printf "%b%s%b" "$color" "$char" "$RESET"
                prev_cx[i]=$rcx
                prev_cy[i]=$rcy
            fi
        done

        sleep_ms 35
    done

    show_cursor
}

# ---------------------------------------------------------------------------
# effect_explosion — Radial burst from a center point
#
# Usage: effect_explosion [origin_x] [origin_y] [rings] [delay_ms]
# ---------------------------------------------------------------------------
effect_explosion() {
    local ox=${1:-$(( TERM_COLS / 2 ))}
    local oy=${2:-$(( TERM_ROWS / 2 ))}
    local rings=${3:-5}
    local delay=${4:-60}

    hide_cursor

    local ring_chars=('·' '░' '▒' '▓' '█' '▓' '▒' '░' '·' ' ')
    local ring_colors=("$THEME_GLOW" "$THEME_FG" "$THEME_ACCENT" "$THEME_COOL" "$THEME_HOT" "$THEME_DIM" "$UI_DIM")

    for (( r=1; r<=rings + ${#ring_chars[@]}; r++ )); do
        # Draw current ring
        local draw_r=$r
        local char_idx=$(( r - 1 ))
        if [[ $char_idx -lt ${#ring_chars[@]} ]]; then
            local char="${ring_chars[$char_idx]}"
            local color="${ring_colors[$(( char_idx % ${#ring_colors[@]} ))]}"

            # Draw ring at radius r (aspect-corrected: x*2 for terminal cells)
            local points=$(( r * 16 ))
            for (( p=0; p<points; p++ )); do
                # Use integer approximation of cos/sin via lookup
                local angle_deg=$(( p * 360 / points ))
                local cos_val sin_val
                # Approximate cos/sin using bc
                local trig
                trig=$(echo "scale=2; c=($angle_deg * 3.14159 / 180); s=s(c); c=c(c); print c, \" \", s" | bc -l 2>/dev/null || echo "0 0")
                read -r cos_val sin_val <<< "$trig"

                local px py
                px=$(echo "scale=0; $ox + $draw_r * $cos_val * 2 / 1" | bc 2>/dev/null || echo "$ox")
                py=$(echo "scale=0; $oy + $draw_r * $sin_val * 0.5 / 1" | bc 2>/dev/null || echo "$oy")

                if [[ $px -ge 1 && $px -le $TERM_COLS && $py -ge 1 && $py -le $TERM_ROWS ]]; then
                    move_cursor "$py" "$px"
                    printf "%b%s%b" "$color" "$char" "$RESET"
                fi
            done
        fi

        # Erase previous ring (r-1)
        if [[ $r -gt 1 ]]; then
            local erase_r=$(( r - 1 ))
            local erase_points=$(( erase_r * 16 ))
            for (( p=0; p<erase_points; p++ )); do
                local angle_deg=$(( p * 360 / erase_points ))
                local trig
                trig=$(echo "scale=2; c=($angle_deg * 3.14159 / 180); s=s(c); c=c(c); print c, \" \", s" | bc -l 2>/dev/null || echo "0 0")
                read -r cos_val sin_val <<< "$trig"
                local px py
                px=$(echo "scale=0; $ox + $erase_r * $cos_val * 2 / 1" | bc 2>/dev/null || echo "$ox")
                py=$(echo "scale=0; $oy + $erase_r * $sin_val * 0.5 / 1" | bc 2>/dev/null || echo "$oy")
                if [[ $px -ge 1 && $px -le $TERM_COLS && $py -ge 1 && $py -le $TERM_ROWS ]]; then
                    move_cursor "$py" "$px"
                    printf " "
                fi
            done
        fi

        sleep_ms "$delay"
    done

    show_cursor
}

# ---------------------------------------------------------------------------
# effect_fountain — Continuous upward particle fountain
#
# Usage: effect_fountain [duration] [intensity]
#   intensity: 1-5 (default: 3)
# ---------------------------------------------------------------------------
effect_fountain() {
    local duration=${1:-4}
    local intensity=${2:-3}

    local ox=$(( TERM_COLS / 2 ))
    local oy=$(( TERM_ROWS - 2 ))

    hide_cursor

    local count=$(( intensity * 5 ))
    local -a px py pvx pvy page pchar pcolor

    local chars=('·' '•' '◦' '○' '◉' '✦' '|' '/' '\\' '-')
    local colors=("$THEME_FG" "$THEME_GLOW" "$THEME_COOL" "$THEME_ACCENT")

    for (( i=0; i<count; i++ )); do
        px[i]=$(( ox * 10 ))
        py[i]=$(( oy * 10 ))
        pvx[i]=$(( (RANDOM % (intensity * 4 + 1)) - intensity * 2 ))
        pvy[i]=$(( -((RANDOM % (intensity * 5)) + intensity * 3) ))
        page[i]=$(( RANDOM % 20 ))  # stagger start times
        pchar[i]="${chars[$((RANDOM % ${#chars[@]}))]}"
        pcolor[i]="${colors[$((RANDOM % ${#colors[@]}))]}"
    done

    local -a prev_x prev_y
    for (( i=0; i<count; i++ )); do prev_x[i]=-1; prev_y[i]=-1; done

    local end_time=$(( SECONDS + duration ))

    while [[ $SECONDS -lt $end_time ]]; do
        for (( i=0; i<count; i++ )); do
            # Erase previous
            local ppx=${prev_x[i]} ppy=${prev_y[i]}
            if [[ $ppx -ge 1 && $ppx -le $TERM_COLS && $ppy -ge 1 && $ppy -le $TERM_ROWS ]]; then
                move_cursor "$ppy" "$ppx"
                printf " "
            fi

            pvy[i]=$(( pvy[i] + _PHYS_GRAVITY ))
            px[i]=$(( px[i] + pvx[i] ))
            py[i]=$(( py[i] + pvy[i] ))
            page[i]=$(( page[i] + 1 ))

            # Reset when particle goes off-screen or hits floor
            if [[ ${py[i]} -ge $(( oy * 10 )) || ${py[i]} -lt 10 || \
                  ${px[i]} -lt 10 || ${px[i]} -gt $(( TERM_COLS * 10 )) ]]; then
                px[i]=$(( ox * 10 ))
                py[i]=$(( oy * 10 ))
                pvx[i]=$(( (RANDOM % (intensity * 4 + 1)) - intensity * 2 ))
                pvy[i]=$(( -((RANDOM % (intensity * 5)) + intensity * 3) ))
                page[i]=0
                pchar[i]="${chars[$((RANDOM % ${#chars[@]}))]}"
                pcolor[i]="${colors[$((RANDOM % ${#colors[@]}))]}"
                prev_x[i]=-1
                prev_y[i]=-1
                continue
            fi

            local rcx=$(( px[i] / 10 ))
            local rcy=$(( py[i] / 10 ))

            local age=${page[i]}
            local color="${pcolor[i]}"
            if [[ $age -gt 15 ]]; then color="$THEME_DIM"; fi

            if [[ $rcx -ge 1 && $rcx -le $TERM_COLS && $rcy -ge 1 && $rcy -le $TERM_ROWS ]]; then
                move_cursor "$rcy" "$rcx"
                printf "%b%s%b" "$color" "${pchar[i]}" "$RESET"
                prev_x[i]=$rcx
                prev_y[i]=$rcy
            fi
        done

        sleep_ms 40
    done

    # Cleanup
    for (( i=0; i<count; i++ )); do
        local ppx=${prev_x[i]} ppy=${prev_y[i]}
        if [[ $ppx -ge 1 && $ppx -le $TERM_COLS && $ppy -ge 1 && $ppy -le $TERM_ROWS ]]; then
            move_cursor "$ppy" "$ppx"
            printf " "
        fi
    done

    show_cursor
}

# ---------------------------------------------------------------------------
# effect_shockwave — Expanding ring shockwave from center
#
# Usage: effect_shockwave [origin_x] [origin_y] [duration]
# ---------------------------------------------------------------------------
effect_shockwave() {
    local ox=${1:-$(( TERM_COLS / 2 ))}
    local oy=${2:-$(( TERM_ROWS / 2 ))}
    local duration=${3:-2}

    hide_cursor

    local max_r=$(( TERM_COLS / 2 ))
    local end_time=$(( SECONDS + duration ))
    local r=1
    local prev_r=0

    while [[ $SECONDS -lt $end_time && $r -le $max_r ]]; do
        # Erase previous ring
        if [[ $prev_r -gt 0 ]]; then
            local erase_points=$(( prev_r * 12 + 1 ))
            for (( p=0; p<erase_points; p++ )); do
                local angle_deg=$(( p * 360 / erase_points ))
                local trig
                trig=$(echo "scale=2; c=($angle_deg * 3.14159 / 180); s=s(c); c=c(c); print c, \" \", s" | bc -l 2>/dev/null || echo "0 0")
                read -r cos_val sin_val <<< "$trig"
                local px py
                px=$(echo "scale=0; $ox + $prev_r * $cos_val * 2 / 1" | bc 2>/dev/null || echo "$ox")
                py=$(echo "scale=0; $oy + $prev_r * $sin_val * 0.5 / 1" | bc 2>/dev/null || echo "$oy")
                if [[ $px -ge 1 && $px -le $TERM_COLS && $py -ge 1 && $py -le $TERM_ROWS ]]; then
                    move_cursor "$py" "$px"
                    printf " "
                fi
            done
        fi

        # Draw current ring
        local fade=$(( r * 100 / max_r ))
        local color
        if [[ $fade -lt 30 ]]; then color="$THEME_GLOW"
        elif [[ $fade -lt 60 ]]; then color="$THEME_FG"
        elif [[ $fade -lt 80 ]]; then color="$THEME_DIM"
        else color="$UI_DIM"; fi

        local ring_char='○'
        [[ $r -lt 3 ]] && ring_char='◉'

        local draw_points=$(( r * 12 + 1 ))
        for (( p=0; p<draw_points; p++ )); do
            local angle_deg=$(( p * 360 / draw_points ))
            local trig
            trig=$(echo "scale=2; c=($angle_deg * 3.14159 / 180); s=s(c); c=c(c); print c, \" \", s" | bc -l 2>/dev/null || echo "0 0")
            read -r cos_val sin_val <<< "$trig"
            local px py
            px=$(echo "scale=0; $ox + $r * $cos_val * 2 / 1" | bc 2>/dev/null || echo "$ox")
            py=$(echo "scale=0; $oy + $r * $sin_val * 0.5 / 1" | bc 2>/dev/null || echo "$oy")
            if [[ $px -ge 1 && $px -le $TERM_COLS && $py -ge 1 && $py -le $TERM_ROWS ]]; then
                move_cursor "$py" "$px"
                printf "%b%s%b" "$color" "$ring_char" "$RESET"
            fi
        done

        prev_r=$r
        r=$(( r + 1 ))
        sleep_ms 50
    done

    # Final erase
    if [[ $prev_r -gt 0 ]]; then
        local erase_points=$(( prev_r * 12 + 1 ))
        for (( p=0; p<erase_points; p++ )); do
            local angle_deg=$(( p * 360 / erase_points ))
            local trig
            trig=$(echo "scale=2; c=($angle_deg * 3.14159 / 180); s=s(c); c=c(c); print c, \" \", s" | bc -l 2>/dev/null || echo "0 0")
            read -r cos_val sin_val <<< "$trig"
            local px py
            px=$(echo "scale=0; $ox + $prev_r * $cos_val * 2 / 1" | bc 2>/dev/null || echo "$ox")
            py=$(echo "scale=0; $oy + $prev_r * $sin_val * 0.5 / 1" | bc 2>/dev/null || echo "$oy")
            if [[ $px -ge 1 && $px -le $TERM_COLS && $py -ge 1 && $py -le $TERM_ROWS ]]; then
                move_cursor "$py" "$px"
                printf " "
            fi
        done
    fi

    show_cursor
}
