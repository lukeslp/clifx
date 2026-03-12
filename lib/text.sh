#!/usr/bin/env bash
# ============================================================================
# text.sh — Text Rendering Primitives
# Purpose: Character-by-character typing, centering, wrapping, padding
# Depends: core.sh, style.sh
# ============================================================================

[[ -n "${_CLIFX_TEXT_LOADED:-}" ]] && return 0
_CLIFX_TEXT_LOADED=1

# --- Type text character by character ---
# Usage: type_text "hello world" [speed_ms] [color]
# Pauses longer on punctuation for natural feel.
type_text() {
    local text="$1"
    local speed=${2:-30}
    local color="${3:-}"

    [[ -n "$color" ]] && printf '%b' "$color"

    for ((i=0; i<${#text}; i++)); do
        local char="${text:$i:1}"

        if [[ "$char" = $'\n' ]]; then
            echo ""
        else
            printf "%s" "$char"
        fi

        case "$char" in
            '.' | '?' | '!') sleep_ms $((speed * 8)) ;;
            ',' | ';' | ':') sleep_ms $((speed * 4)) ;;
            ' ')             sleep_ms $((speed * 2)) ;;
            $'\n')           sleep_ms $((speed * 4)) ;;
            *)               sleep_ms "$speed" ;;
        esac
    done

    [[ -n "$color" ]] && printf '%b' "$RESET"
    echo ""
}

# --- Center text on current row ---
# Usage: center_text "hello" [color]
center_text() {
    local text="$1"
    local color="${2:-}"
    local col
    col=$(center_col "$text")

    printf "%*s" "$col" ""
    [[ -n "$color" ]] && printf '%b' "$color"
    printf "%s" "$text"
    [[ -n "$color" ]] && printf '%b' "$RESET"
    echo ""
}

# --- Pad text to width ---
# Usage: pad_text "hello" 40 [left|center|right]
pad_text() {
    local text="$1"
    local width=$2
    local align="${3:-left}"
    local text_len=${#text}
    local pad

    if [[ "$text_len" -ge "$width" ]]; then
        printf "%s" "$text"
        return
    fi

    pad=$((width - text_len))

    case "$align" in
        left)
            printf "%s%*s" "$text" "$pad" ""
            ;;
        right)
            printf "%*s%s" "$pad" "" "$text"
            ;;
        center)
            local left_pad=$((pad / 2))
            local right_pad=$((pad - left_pad))
            printf "%*s%s%*s" "$left_pad" "" "$text" "$right_pad" ""
            ;;
    esac
}

# --- Word wrap to width ---
# Usage: wrap_text "long text here" 40
# Outputs wrapped lines to stdout, one per line.
wrap_text() {
    local text="$1"
    local width=${2:-$CONTENT_WIDTH}
    local line=""
    local word

    for word in $text; do
        if [[ -z "$line" ]]; then
            line="$word"
        elif [[ $(( ${#line} + 1 + ${#word} )) -le "$width" ]]; then
            line="$line $word"
        else
            echo "$line"
            line="$word"
        fi
    done
    [[ -n "$line" ]] && echo "$line"
}

# --- Truncate with suffix ---
# Usage: truncate_text "long text" 10 "..."
truncate_text() {
    local text="$1"
    local max_len=$2
    local suffix="${3:-...}"

    if [[ ${#text} -le "$max_len" ]]; then
        printf "%s" "$text"
    else
        local cut_len=$((max_len - ${#suffix}))
        printf "%s%s" "${text:0:$cut_len}" "$suffix"
    fi
}

# --- Indent text block ---
# Usage: echo "text" | indent 4
# Or:    indent "text" 4
indent() {
    local spaces
    if [[ $# -ge 2 ]]; then
        # indent "text" N
        local text="$1"
        spaces=$2
        while IFS= read -r line; do
            printf "%*s%s\n" "$spaces" "" "$line"
        done <<< "$text"
    else
        # Pipe mode: stdin | indent N
        spaces=${1:-2}
        while IFS= read -r line; do
            printf "%*s%s\n" "$spaces" "" "$line"
        done
    fi
}
