#!/usr/bin/env bash
# ============================================================================
# manifest_data.sh — Real-Time Data Visualization Effects
#
# Purpose: Read live system data (CPU, memory, disk, network, processes)
#          and render it as animated terminal visualizations. All effects
#          update in real-time and respect CLIFX_SPEED_MULT for timing.
#
# Effects:
#   effect_cpu_sparkline   — Rolling CPU usage sparkline graph
#   effect_mem_bars        — Memory usage bar chart (total/used/free/cache)
#   effect_disk_bars       — Disk usage bars for all mounted filesystems
#   effect_net_monitor     — Network I/O rate monitor with sparklines
#   effect_proc_heatmap    — Process CPU heatmap (top N processes)
#   effect_sysinfo_panel   — Full-screen system dashboard
#
# Sourced by manifest.sh — do not run directly.
# ============================================================================

[[ -n "${_CLIFX_MANIFEST_DATA_LOADED:-}" ]] && return 0
_CLIFX_MANIFEST_DATA_LOADED=1

# ---------------------------------------------------------------------------
# Internal: sparkline rendering
# ---------------------------------------------------------------------------

# Sparkline block characters (8 levels)
_SPARK_CHARS=('▁' '▂' '▃' '▄' '▅' '▆' '▇' '█')

# Render a sparkline from an array of values (0-100)
# Usage: _render_sparkline values_array_name width [color]
_render_sparkline() {
    local -n _spark_vals="$1"
    local width="$2"
    local color="${3:-$THEME_FG}"

    local n=${#_spark_vals[@]}
    local result=""

    # Use the last `width` values
    local start=$(( n > width ? n - width : 0 ))

    for (( i=start; i<n; i++ )); do
        local val=${_spark_vals[i]}
        # Clamp to 0-100
        [[ $val -lt 0 ]] && val=0
        [[ $val -gt 100 ]] && val=100
        local idx=$(( val * 7 / 100 ))
        result+="${_SPARK_CHARS[$idx]}"
    done

    # Pad with spaces if fewer values than width
    local actual=$(( n - start ))
    if [[ $actual -lt $width ]]; then
        local pad=$(( width - actual ))
        result="$(printf '%*s' "$pad" "")$result"
    fi

    printf "%b%s%b" "$color" "$result" "$RESET"
}

# ---------------------------------------------------------------------------
# Internal: get CPU usage percentage (0-100)
# ---------------------------------------------------------------------------
_get_cpu_pct() {
    # Read /proc/stat twice with a short interval for accuracy
    local line1 line2
    line1=$(grep '^cpu ' /proc/stat 2>/dev/null || echo "cpu 0 0 0 0 0 0 0")
    sleep_ms 100
    line2=$(grep '^cpu ' /proc/stat 2>/dev/null || echo "cpu 0 0 0 0 0 0 0")

    local -a f1 f2
    read -r -a f1 <<< "$line1"
    read -r -a f2 <<< "$line2"

    local idle1=$(( f1[4] + (f1[5]:-0) ))
    local idle2=$(( f2[4] + (f2[5]:-0) ))
    local total1=0 total2=0

    for (( i=1; i<${#f1[@]}; i++ )); do total1=$(( total1 + f1[i] )); done
    for (( i=1; i<${#f2[@]}; i++ )); do total2=$(( total2 + f2[i] )); done

    local dtotal=$(( total2 - total1 ))
    local didle=$(( idle2 - idle1 ))

    if [[ $dtotal -gt 0 ]]; then
        echo $(( (dtotal - didle) * 100 / dtotal ))
    else
        echo 0
    fi
}

# ---------------------------------------------------------------------------
# Internal: get memory info (outputs "total_kb used_kb free_kb cache_kb")
# ---------------------------------------------------------------------------
_get_mem_info() {
    local total=0 free=0 buffers=0 cached=0 available=0

    while IFS=: read -r key val; do
        val="${val//[[:space:]kB]/}"
        case "$key" in
            MemTotal)     total=$val ;;
            MemFree)      free=$val ;;
            Buffers)      buffers=$val ;;
            Cached)       cached=$val ;;
            MemAvailable) available=$val ;;
        esac
    done < /proc/meminfo 2>/dev/null

    local used=$(( total - free - buffers - cached ))
    echo "$total $used $free $cached"
}

# ---------------------------------------------------------------------------
# effect_cpu_sparkline — Rolling CPU usage sparkline
#
# Usage: effect_cpu_sparkline [duration] [update_interval_s]
# ---------------------------------------------------------------------------
effect_cpu_sparkline() {
    local duration=${1:-10}
    local interval=${2:-1}

    hide_cursor

    local width=$(( TERM_COLS - 20 ))
    [[ $width -lt 10 ]] && width=10

    local -a history=()
    local end_time=$(( SECONDS + duration ))

    while [[ $SECONDS -lt $end_time ]]; do
        local cpu
        cpu=$(_get_cpu_pct)
        history+=("$cpu")

        # Keep history bounded
        while [[ ${#history[@]} -gt $width ]]; do
            history=("${history[@]:1}")
        done

        # Render
        move_cursor 1 1
        printf "${THEME_GLOW}${BOLD}CPU Usage${RESET}  "
        printf "${THEME_ACCENT}%3d%%${RESET}\n" "$cpu"

        move_cursor 2 1
        _render_sparkline history "$width" "$THEME_FG"
        printf "\n"

        move_cursor 3 1
        printf "${UI_DIM}%*s${RESET}" "$width" ""
        move_cursor 3 1
        printf "${UI_DIM}0%%"
        move_cursor 3 $(( width / 2 ))
        printf "50%%"
        move_cursor 3 $(( width - 3 ))
        printf "100%%${RESET}"

        move_cursor 5 1
        printf "${UI_DIM}Press q to exit${RESET}"

        sleep_ms $(( interval * 1000 ))
    done

    show_cursor
}

# ---------------------------------------------------------------------------
# effect_mem_bars — Memory usage bar chart
#
# Usage: effect_mem_bars [duration] [update_interval_s]
# ---------------------------------------------------------------------------
effect_mem_bars() {
    local duration=${1:-8}
    local interval=${2:-2}

    hide_cursor

    local bar_width=$(( TERM_COLS - 30 ))
    [[ $bar_width -lt 10 ]] && bar_width=10

    local end_time=$(( SECONDS + duration ))

    while [[ $SECONDS -lt $end_time ]]; do
        read -r total used free cached <<< "$(_get_mem_info)"

        local total_mb=$(( total / 1024 ))
        local used_mb=$(( used / 1024 ))
        local free_mb=$(( free / 1024 ))
        local cached_mb=$(( cached / 1024 ))

        local used_pct=$(( total > 0 ? used * 100 / total : 0 ))
        local cached_pct=$(( total > 0 ? cached * 100 / total : 0 ))
        local free_pct=$(( 100 - used_pct - cached_pct ))
        [[ $free_pct -lt 0 ]] && free_pct=0

        move_cursor 1 1
        printf "${THEME_GLOW}${BOLD}Memory Usage${RESET}  ${UI_DIM}%d MB total${RESET}\n\n" "$total_mb"

        # Used bar
        local used_fill=$(( bar_width * used_pct / 100 ))
        local used_bar
        used_bar=$(printf '%*s' "$used_fill" "" | tr ' ' '█')
        local used_empty
        used_empty=$(printf '%*s' "$(( bar_width - used_fill ))" "" | tr ' ' '░')
        printf "  ${THEME_FG}%-8s${RESET} ${THEME_ACCENT}%s${RESET}%s ${THEME_ACCENT}%4d MB (%d%%)${RESET}\n" \
            "Used" "$used_bar" "$used_empty" "$used_mb" "$used_pct"

        # Cached bar
        local cached_fill=$(( bar_width * cached_pct / 100 ))
        local cached_bar
        cached_bar=$(printf '%*s' "$cached_fill" "" | tr ' ' '█')
        local cached_empty
        cached_empty=$(printf '%*s' "$(( bar_width - cached_fill ))" "" | tr ' ' '░')
        printf "  ${THEME_COOL}%-8s${RESET} ${THEME_COOL}%s${RESET}%s ${THEME_COOL}%4d MB (%d%%)${RESET}\n" \
            "Cached" "$cached_bar" "$cached_empty" "$cached_mb" "$cached_pct"

        # Free bar
        local free_fill=$(( bar_width * free_pct / 100 ))
        local free_bar
        free_bar=$(printf '%*s' "$free_fill" "" | tr ' ' '█')
        local free_empty
        free_empty=$(printf '%*s' "$(( bar_width - free_fill ))" "" | tr ' ' '░')
        printf "  ${THEME_DIM}%-8s${RESET} ${THEME_DIM}%s${RESET}%s ${THEME_DIM}%4d MB (%d%%)${RESET}\n" \
            "Free" "$free_bar" "$free_empty" "$free_mb" "$free_pct"

        printf "\n  ${UI_DIM}Updates every %ds  —  q to exit${RESET}\n" "$interval"

        sleep_ms $(( interval * 1000 ))
    done

    show_cursor
}

# ---------------------------------------------------------------------------
# effect_disk_bars — Disk usage bars for all mounted filesystems
#
# Usage: effect_disk_bars [duration]
# ---------------------------------------------------------------------------
effect_disk_bars() {
    local duration=${1:-6}

    hide_cursor

    local bar_width=$(( TERM_COLS - 45 ))
    [[ $bar_width -lt 10 ]] && bar_width=10

    local end_time=$(( SECONDS + duration ))

    while [[ $SECONDS -lt $end_time ]]; do
        move_cursor 1 1
        printf "${THEME_GLOW}${BOLD}Disk Usage${RESET}\n\n"

        local row=3
        while IFS= read -r line; do
            # Parse df output: Filesystem Size Used Avail Use% Mountpoint
            local fs size used avail pct mount
            read -r fs size used avail pct mount <<< "$line"

            # Skip header and special filesystems
            [[ "$fs" == "Filesystem" ]] && continue
            [[ "$fs" == tmpfs* || "$fs" == devtmpfs* || "$fs" == udev* ]] && continue
            [[ -z "$mount" ]] && continue

            local pct_num="${pct//%/}"
            [[ -z "$pct_num" || ! "$pct_num" =~ ^[0-9]+$ ]] && continue

            local fill=$(( bar_width * pct_num / 100 ))
            local bar
            bar=$(printf '%*s' "$fill" "" | tr ' ' '█')
            local empty
            empty=$(printf '%*s' "$(( bar_width - fill ))" "" | tr ' ' '░')

            # Color by usage level
            local color="$THEME_FG"
            [[ $pct_num -gt 70 ]] && color="$THEME_WARN"
            [[ $pct_num -gt 90 ]] && color="$UI_ERROR"

            move_cursor "$row" 1
            printf "  ${THEME_ACCENT}%-20s${RESET} %s%s${RESET}%s ${color}%4s${RESET}  ${UI_DIM}%s${RESET}\n" \
                "$mount" "$color" "$bar" "$empty" "$pct" "$size"

            row=$(( row + 1 ))
            [[ $row -gt $(( TERM_ROWS - 3 )) ]] && break
        done < <(df -h 2>/dev/null)

        move_cursor $(( TERM_ROWS - 1 )) 1
        printf "${UI_DIM}q to exit${RESET}"

        sleep_ms 2000
    done

    show_cursor
}

# ---------------------------------------------------------------------------
# effect_net_monitor — Network I/O rate monitor
#
# Usage: effect_net_monitor [duration] [interface]
# ---------------------------------------------------------------------------
effect_net_monitor() {
    local duration=${1:-10}
    local iface="${2:-}"

    hide_cursor

    # Auto-detect primary interface if not specified
    if [[ -z "$iface" ]]; then
        iface=$(ip route 2>/dev/null | grep '^default' | awk '{print $5}' | head -1)
        [[ -z "$iface" ]] && iface=$(ls /sys/class/net/ 2>/dev/null | grep -v lo | head -1)
        [[ -z "$iface" ]] && iface="lo"
    fi

    local width=$(( (TERM_COLS - 25) / 2 ))
    [[ $width -lt 5 ]] && width=5

    local -a rx_history=() tx_history=()
    local prev_rx=0 prev_tx=0

    # Read initial counters
    if [[ -f "/sys/class/net/$iface/statistics/rx_bytes" ]]; then
        prev_rx=$(cat "/sys/class/net/$iface/statistics/rx_bytes" 2>/dev/null || echo 0)
        prev_tx=$(cat "/sys/class/net/$iface/statistics/tx_bytes" 2>/dev/null || echo 0)
    fi

    local end_time=$(( SECONDS + duration ))

    while [[ $SECONDS -lt $end_time ]]; do
        sleep_ms 1000

        local curr_rx curr_tx
        curr_rx=$(cat "/sys/class/net/$iface/statistics/rx_bytes" 2>/dev/null || echo 0)
        curr_tx=$(cat "/sys/class/net/$iface/statistics/tx_bytes" 2>/dev/null || echo 0)

        local rx_rate=$(( (curr_rx - prev_rx) / 1024 ))  # KB/s
        local tx_rate=$(( (curr_tx - prev_tx) / 1024 ))  # KB/s
        prev_rx=$curr_rx
        prev_tx=$curr_tx

        # Scale to 0-100 (cap at 10 MB/s = 10240 KB/s)
        local rx_pct=$(( rx_rate > 10240 ? 100 : rx_rate * 100 / 10240 ))
        local tx_pct=$(( tx_rate > 10240 ? 100 : tx_rate * 100 / 10240 ))

        rx_history+=("$rx_pct")
        tx_history+=("$tx_pct")
        while [[ ${#rx_history[@]} -gt $width ]]; do rx_history=("${rx_history[@]:1}"); done
        while [[ ${#tx_history[@]} -gt $width ]]; do tx_history=("${tx_history[@]:1}"); done

        move_cursor 1 1
        printf "${THEME_GLOW}${BOLD}Network: %s${RESET}\n\n" "$iface"

        printf "  ${THEME_COOL}RX${RESET} "
        _render_sparkline rx_history "$width" "$THEME_COOL"
        printf "  ${THEME_COOL}%6d KB/s${RESET}\n" "$rx_rate"

        printf "  ${THEME_HOT}TX${RESET} "
        _render_sparkline tx_history "$width" "$THEME_HOT"
        printf "  ${THEME_HOT}%6d KB/s${RESET}\n" "$tx_rate"

        printf "\n  ${UI_DIM}q to exit${RESET}"
    done

    show_cursor
}

# ---------------------------------------------------------------------------
# effect_proc_heatmap — Process CPU heatmap (top N processes)
#
# Usage: effect_proc_heatmap [duration] [top_n]
# ---------------------------------------------------------------------------
effect_proc_heatmap() {
    local duration=${1:-8}
    local top_n=${2:-10}

    hide_cursor

    local end_time=$(( SECONDS + duration ))

    while [[ $SECONDS -lt $end_time ]]; do
        move_cursor 1 1
        printf "${THEME_GLOW}${BOLD}Process CPU Heatmap${RESET}  ${UI_DIM}(top %d)${RESET}\n\n" "$top_n"

        local row=3
        while IFS= read -r line; do
            local cpu pid comm
            cpu=$(echo "$line" | awk '{print $1}')
            pid=$(echo "$line" | awk '{print $2}')
            comm=$(echo "$line" | awk '{$1=$2=""; print $0}' | sed 's/^ *//')

            [[ -z "$cpu" || "$cpu" == "%CPU" ]] && continue

            # Convert cpu to integer (strip decimal)
            local cpu_int="${cpu%%.*}"
            [[ -z "$cpu_int" || ! "$cpu_int" =~ ^[0-9]+$ ]] && cpu_int=0

            # Color by CPU usage
            local color="$THEME_DIM"
            [[ $cpu_int -gt 5  ]] && color="$THEME_FG"
            [[ $cpu_int -gt 20 ]] && color="$THEME_ACCENT"
            [[ $cpu_int -gt 50 ]] && color="$THEME_HOT"
            [[ $cpu_int -gt 80 ]] && color="$THEME_WARN"

            # Heat block
            local heat_w=$(( cpu_int > 20 ? 20 : cpu_int ))
            local heat_bar
            heat_bar=$(printf '%*s' "$heat_w" "" | tr ' ' '█')
            local heat_empty
            heat_empty=$(printf '%*s' "$(( 20 - heat_w ))" "" | tr ' ' '░')

            move_cursor "$row" 1
            printf "  %b%s%b%s  %b%5s%%  %5s  %-20s%b\n" \
                "$color" "$heat_bar" "$RESET" "$heat_empty" \
                "$color" "$cpu" "$pid" "${comm:0:20}" "$RESET"

            row=$(( row + 1 ))
            [[ $row -gt $(( top_n + 2 )) ]] && break
        done < <(ps aux --sort=-%cpu 2>/dev/null | awk 'NR>1 {print $3, $2, $11}' | head -"$top_n")

        move_cursor $(( TERM_ROWS - 1 )) 1
        printf "${UI_DIM}q to exit${RESET}"

        sleep_ms 2000
    done

    show_cursor
}

# ---------------------------------------------------------------------------
# effect_sysinfo_panel — Full-screen system dashboard
#
# Usage: effect_sysinfo_panel [duration]
# ---------------------------------------------------------------------------
effect_sysinfo_panel() {
    local duration=${1:-15}

    hide_cursor
    clear_screen

    local end_time=$(( SECONDS + duration ))

    while [[ $SECONDS -lt $end_time ]]; do
        # Gather data
        local cpu
        cpu=$(_get_cpu_pct)
        read -r mem_total mem_used mem_free mem_cached <<< "$(_get_mem_info)"
        local mem_pct=$(( mem_total > 0 ? mem_used * 100 / mem_total : 0 ))
        local uptime_str
        uptime_str=$(uptime -p 2>/dev/null || uptime | sed 's/.*up /up /')
        local load_avg
        load_avg=$(cat /proc/loadavg 2>/dev/null | awk '{print $1, $2, $3}')
        local hostname
        hostname=$(hostname 2>/dev/null || echo "unknown")
        local kernel
        kernel=$(uname -r 2>/dev/null || echo "unknown")

        # Header
        move_cursor 1 1
        printf "${THEME_GLOW}${BOLD}%-${TERM_COLS}s${RESET}\n" \
            "  ◈ SYSTEM MONITOR — $hostname"

        # CPU
        local cpu_bar_w=$(( TERM_COLS / 2 - 15 ))
        local cpu_fill=$(( cpu_bar_w * cpu / 100 ))
        local cpu_bar
        cpu_bar=$(printf '%*s' "$cpu_fill" "" | tr ' ' '█')
        local cpu_empty
        cpu_empty=$(printf '%*s' "$(( cpu_bar_w - cpu_fill ))" "" | tr ' ' '░')
        move_cursor 3 1
        printf "  ${THEME_FG}CPU${RESET}  ${THEME_ACCENT}%s${RESET}%s  ${THEME_ACCENT}%3d%%${RESET}" \
            "$cpu_bar" "$cpu_empty" "$cpu"

        # Memory
        local mem_bar_w=$(( TERM_COLS / 2 - 15 ))
        local mem_fill=$(( mem_bar_w * mem_pct / 100 ))
        local mem_bar
        mem_bar=$(printf '%*s' "$mem_fill" "" | tr ' ' '█')
        local mem_empty
        mem_empty=$(printf '%*s' "$(( mem_bar_w - mem_fill ))" "" | tr ' ' '░')
        move_cursor 4 1
        printf "  ${THEME_FG}MEM${RESET}  ${THEME_COOL}%s${RESET}%s  ${THEME_COOL}%3d%%${RESET}  ${UI_DIM}%d/%d MB${RESET}" \
            "$mem_bar" "$mem_empty" "$mem_pct" \
            "$(( mem_used / 1024 ))" "$(( mem_total / 1024 ))"

        # System info
        move_cursor 6 1
        printf "  ${UI_DIM}Kernel:${RESET}  ${THEME_FG}%s${RESET}" "$kernel"
        move_cursor 7 1
        printf "  ${UI_DIM}Uptime:${RESET}  ${THEME_FG}%s${RESET}" "$uptime_str"
        move_cursor 8 1
        printf "  ${UI_DIM}Load:${RESET}    ${THEME_FG}%s${RESET}" "$load_avg"

        # Top processes
        move_cursor 10 1
        printf "${THEME_GLOW}${BOLD}  Top Processes${RESET}\n"
        local proc_row=11
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            local pcpu ppid pcomm
            pcpu=$(echo "$line" | awk '{print $1}')
            ppid=$(echo "$line" | awk '{print $2}')
            pcomm=$(echo "$line" | awk '{$1=$2=""; print $0}' | sed 's/^ *//')
            [[ "$pcpu" == "%CPU" ]] && continue

            local pcpu_int="${pcpu%%.*}"
            [[ -z "$pcpu_int" || ! "$pcpu_int" =~ ^[0-9]+$ ]] && pcpu_int=0

            local pcolor="$THEME_DIM"
            [[ $pcpu_int -gt 5  ]] && pcolor="$THEME_FG"
            [[ $pcpu_int -gt 30 ]] && pcolor="$THEME_HOT"

            move_cursor "$proc_row" 1
            printf "  %b%5s%%  %5s  %-30s%b\n" \
                "$pcolor" "$pcpu" "$ppid" "${pcomm:0:30}" "$RESET"
            proc_row=$(( proc_row + 1 ))
            [[ $proc_row -gt $(( TERM_ROWS - 3 )) ]] && break
        done < <(ps aux --sort=-%cpu 2>/dev/null | awk 'NR>1 {print $3, $2, $11}' | head -8)

        # Footer
        move_cursor "$TERM_ROWS" 1
        printf "${THEME_DIM}%-${TERM_COLS}s${RESET}" "  q to exit"

        sleep_ms 2000
    done

    show_cursor
}
