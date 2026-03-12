#!/usr/bin/env bash
# ============================================================================
# progress.sh — Progress Indicators
# Purpose: Spinners, progress bars, fake install sequences
# Depends: core.sh, style.sh
# ============================================================================

[[ -n "${_CLIFX_PROGRESS_LOADED:-}" ]] && return 0
_CLIFX_PROGRESS_LOADED=1

# --- Spinner ---
# Run a command with a spinner display
# Usage: spinner "Loading..." some_command arg1 arg2
spinner() {
    local message="$1"
    shift
    local spin_chars=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local pid

    "$@" &
    pid=$!

    local i=0
    printf "  "
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  %s %s" "${spin_chars[$((i % ${#spin_chars[@]}))]}" "$message"
        sleep_ms 80
        i=$((i + 1))
    done

    wait "$pid"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        printf "\r  %b✓%b %s\n" "$UI_SUCCESS" "$RESET" "$message"
    else
        printf "\r  %b✗%b %s\n" "$UI_ERROR" "$RESET" "$message"
    fi
    return $exit_code
}

# --- Progress bar ---
# Usage: progress_bar <current> <total> [width] [color]
progress_bar() {
    local current=$1
    local total=$2
    local width=${3:-30}
    local color="${4:-$UI_SUCCESS}"

    local pct=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))

    printf "  ["
    printf '%b' "$color"
    for ((i=0; i<filled; i++)); do printf "█"; done
    printf '%b' "$RESET"
    printf '%b' "$DIM"
    for ((i=0; i<empty; i++)); do printf "░"; done
    printf '%b' "$RESET"
    printf "] %3d%%" "$pct"
}

# --- Fake progress with dots ---
# Usage: fake_progress "Loading data" [duration_ms]
fake_progress() {
    local message="$1"
    local duration=${2:-2000}
    local dot_count=$((duration / 400))
    [[ "$dot_count" -lt 3 ]] && dot_count=3

    printf "  %s" "$message"
    for ((i=0; i<dot_count; i++)); do
        sleep_ms $((duration / dot_count))
        printf "."
    done
    echo " done"
}

# --- Checklist item ---
# Usage: checklist_item "Verified checksums" done
# Status: done, fail, pending
checklist_item() {
    local message="$1"
    local status="${2:-pending}"

    case "$status" in
        done|completed|pass)
            printf "  %b[✓]%b %s\n" "$UI_SUCCESS" "$RESET" "$message"
            ;;
        fail|failed|error)
            printf "  %b[✗]%b %s\n" "$UI_ERROR" "$RESET" "$message"
            ;;
        pending|*)
            printf "  %b[ ]%b %s\n" "$DIM" "$RESET" "$message"
            ;;
    esac
}

# --- Fake package install line ---
# Usage: install_line "chalk@5.3.0"
install_line() {
    local pkg="$1"
    printf "  %b    installing %b%s%b...%b" "$DIM" "$RESET" "$pkg" "$DIM" "$RESET"
    sleep_ms $((200 + RANDOM % 800))
    printf " %b✓%b\n" "$UI_SUCCESS" "$RESET"
}
