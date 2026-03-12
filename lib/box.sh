#!/usr/bin/env bash
# ============================================================================
# box.sh — Box Drawing
# Purpose: Frames, panels, bordered content
# Depends: core.sh, style.sh, terminal.sh
# ============================================================================

[[ -n "${_CLIFX_BOX_LOADED:-}" ]] && return 0
_CLIFX_BOX_LOADED=1

# --- Box character sets ---
# Each set: tl, t, tr, l, r, bl, b, br  (top-left, top, top-right, etc.)
_box_chars() {
    local style="${1:-single}"
    case "$style" in
        single)  echo '┌ ─ ┐ │ │ └ ─ ┘' ;;
        double)  echo '╔ ═ ╗ ║ ║ ╚ ═ ╝' ;;
        rounded) echo '╭ ─ ╮ │ │ ╰ ─ ╯' ;;
        heavy)   echo '┏ ━ ┓ ┃ ┃ ┗ ━ ┛' ;;
        *)       echo '┌ ─ ┐ │ │ └ ─ ┘' ;;
    esac
}

# --- Draw a box outline ---
# Usage: draw_box <width> <height> [style] [color]
draw_box() {
    local width=$1
    local height=$2
    local style="${3:-single}"
    local color="${4:-}"

    local chars
    read -r -a chars <<< "$(_box_chars "$style")"
    local tl="${chars[0]}" t="${chars[1]}" tr="${chars[2]}"
    local l="${chars[3]}" r="${chars[4]}"
    local bl="${chars[5]}" b="${chars[6]}" br="${chars[7]}"

    local inner=$((width - 2))

    [[ -n "$color" ]] && printf '%b' "$color"

    # Top border
    printf "%s" "$tl"
    for ((i=0; i<inner; i++)); do printf "%s" "$t"; done
    printf "%s\n" "$tr"

    # Side borders
    for ((row=0; row<height-2; row++)); do
        printf "%s" "$l"
        printf "%*s" "$inner" ""
        printf "%s\n" "$r"
    done

    # Bottom border
    printf "%s" "$bl"
    for ((i=0; i<inner; i++)); do printf "%s" "$b"; done
    printf "%s\n" "$br"

    [[ -n "$color" ]] && printf '%b' "$RESET"
    return 0
}

# --- Draw a box around text ---
# Usage: draw_box_text "hello world" [style] [color] [padding]
draw_box_text() {
    local text="$1"
    local style="${2:-single}"
    local color="${3:-}"
    local padding=${4:-1}

    local chars
    read -r -a chars <<< "$(_box_chars "$style")"
    local tl="${chars[0]}" t="${chars[1]}" tr="${chars[2]}"
    local l="${chars[3]}" r="${chars[4]}"
    local bl="${chars[5]}" b="${chars[6]}" br="${chars[7]}"

    # Split text into lines
    local -a lines=()
    local max_len=0
    while IFS= read -r line; do
        lines+=("$line")
        [[ ${#line} -gt $max_len ]] && max_len=${#line}
    done <<< "$text"

    local inner=$((max_len + padding * 2))

    [[ -n "$color" ]] && printf '%b' "$color"

    # Top
    printf "%s" "$tl"
    for ((i=0; i<inner; i++)); do printf "%s" "$t"; done
    printf "%s\n" "$tr"

    # Padding rows above text
    for ((p=0; p<padding; p++)); do
        printf "%s%*s%s\n" "$l" "$inner" "" "$r"
    done

    # Content rows
    for line in "${lines[@]}"; do
        local line_len=${#line}
        local right_pad=$((inner - padding - line_len))
        [[ "$right_pad" -lt 0 ]] && right_pad=0
        printf "%s%*s%s%*s%s\n" "$l" "$padding" "" "$line" "$right_pad" "" "$r"
    done

    # Padding rows below text
    for ((p=0; p<padding; p++)); do
        printf "%s%*s%s\n" "$l" "$inner" "" "$r"
    done

    # Bottom
    printf "%s" "$bl"
    for ((i=0; i<inner; i++)); do printf "%s" "$b"; done
    printf "%s\n" "$br"

    [[ -n "$color" ]] && printf '%b' "$RESET"
    return 0
}

# --- Draw a header bar ---
# Usage: draw_header "Title" [style] [color]
draw_header() {
    local text="$1"
    local style="${2:-thick}"
    local color="${3:-}"

    local chars
    read -r -a chars <<< "$(_box_chars "$style")"
    local t="${chars[1]}"

    local width=$CONTENT_WIDTH
    local text_len=${#text}
    local side=$(( (width - text_len - 4) / 2 ))
    [[ "$side" -lt 1 ]] && side=1

    [[ -n "$color" ]] && printf '%b' "$color"

    for ((i=0; i<side; i++)); do printf "%s" "$t"; done
    printf " %s " "$text"
    local right=$((width - side - text_len - 2))
    for ((i=0; i<right; i++)); do printf "%s" "$t"; done
    echo ""

    [[ -n "$color" ]] && printf '%b' "$RESET"
    return 0
}

# --- Draw a multi-line panel ---
# Usage: draw_panel [style] [color] <<< "line1\nline2\nline3"
# Or:    draw_panel [style] [color] "line1" "line2" "line3"
draw_panel() {
    local style="${1:-single}"
    local color="${2:-}"
    shift 2 2>/dev/null || true

    local -a lines=()
    if [[ $# -gt 0 ]]; then
        lines=("$@")
    else
        while IFS= read -r line; do
            lines+=("$line")
        done
    fi

    local content
    content=$(printf '%s\n' "${lines[@]}")
    draw_box_text "$content" "$style" "$color"
}
