#!/usr/bin/env bash
# ============================================================================
# ascii.sh — ASCII Art Rendering
# Purpose: Display and animate multi-line ASCII art
# Depends: core.sh, style.sh, terminal.sh
# ============================================================================

[[ -n "${_CLIFX_ASCII_LOADED:-}" ]] && return 0
_CLIFX_ASCII_LOADED=1

# --- Render ASCII art ---
# Usage: render_art "art_text" [color] [center]
# Or:    render_art < file.txt
render_art() {
    local color="${2:-}"
    local do_center="${3:-false}"

    local -a lines=()
    if [[ $# -ge 1 && -n "$1" ]]; then
        while IFS= read -r line; do
            lines+=("$line")
        done <<< "$1"
    else
        while IFS= read -r line; do
            lines+=("$line")
        done
    fi

    [[ -n "$color" ]] && printf '%b' "$color"

    for line in "${lines[@]}"; do
        if [[ "$do_center" == "true" ]]; then
            local col
            col=$(center_col "$line")
            printf "%*s%s\n" "$col" "" "$line"
        else
            printf "%s\n" "$line"
        fi
    done

    [[ -n "$color" ]] && printf '%b' "$RESET"
    return 0
}

# --- Render ASCII art with line-by-line reveal ---
# Usage: render_art_animated "art_text" [speed_ms] [color] [center]
render_art_animated() {
    local art="$1"
    local speed=${2:-100}
    local color="${3:-}"
    local do_center="${4:-false}"

    local -a lines=()
    while IFS= read -r line; do
        lines+=("$line")
    done <<< "$art"

    [[ -n "$color" ]] && printf '%b' "$color"

    for line in "${lines[@]}"; do
        if [[ "$do_center" == "true" ]]; then
            local col
            col=$(center_col "$line")
            printf "%*s%s\n" "$col" "" "$line"
        else
            printf "%s\n" "$line"
        fi
        sleep_ms "$speed"
    done

    [[ -n "$color" ]] && printf '%b' "$RESET"
    return 0
}

# --- Assemble fragments ---
# Combine fragment files from a directory into composite output
# Usage: assemble_fragments <dir> [color]
assemble_fragments() {
    local dir="$1"
    local color="${2:-}"

    if [[ ! -d "$dir" ]]; then
        echo "Fragment directory not found: $dir" >&2
        return 1
    fi

    local combined=""
    local f
    for f in "$dir"/*; do
        [[ -f "$f" ]] || continue
        if [[ -n "$combined" ]]; then
            combined+=$'\n'
        fi
        combined+="$(cat "$f")"
    done

    render_art "$combined" "$color"
}
