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

# --- Play frame animation ---
# Play a text file containing frames delimited by "--- Frame N ---"
# Usage: play_frames <file> [fps] [loops] [color]
#   file:  Path to animation file (--- Frame N --- delimited)
#   fps:   Frames per second (default: 12)
#   loops: Number of loops, 0=infinite (default: 1)
#   color: Optional color escape code
play_frames() {
    local file="$1"
    local fps=${2:-12}
    local loops=${3:-1}
    local color="${4:-}"

    if [[ ! -f "$file" ]]; then
        echo "Animation file not found: $file" >&2
        return 1
    fi

    local delay_ms=$((1000 / fps))

    # Parse frames: split on "--- Frame" delimiter lines
    local -a frames=()
    local current_frame=""
    local in_frame=0

    while IFS= read -r line; do
        if [[ "$line" =~ ^---\ Frame ]]; then
            if [[ $in_frame -eq 1 && -n "$current_frame" ]]; then
                frames+=("$current_frame")
            fi
            current_frame=""
            in_frame=1
            continue
        fi
        if [[ $in_frame -eq 1 ]]; then
            if [[ -n "$current_frame" ]]; then
                current_frame+=$'\n'"$line"
            else
                current_frame="$line"
            fi
        fi
    done < "$file"
    # Capture last frame
    [[ $in_frame -eq 1 && -n "$current_frame" ]] && frames+=("$current_frame")

    local num_frames=${#frames[@]}
    if [[ $num_frames -eq 0 ]]; then
        echo "No frames found in: $file" >&2
        return 1
    fi

    hide_cursor

    local loop_count=0
    while true; do
        for ((f=0; f<num_frames; f++)); do
            printf '\033[2J\033[H'  # clear screen + home
            [[ -n "$color" ]] && printf '%b' "$color"
            printf '%s' "${frames[$f]}"
            [[ -n "$color" ]] && printf '%b' "$RESET"
            sleep_ms "$delay_ms"
        done

        loop_count=$((loop_count + 1))
        if [[ $loops -gt 0 && $loop_count -ge $loops ]]; then
            break
        fi
    done

    show_cursor
}
