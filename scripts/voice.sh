#!/usr/bin/env bash
# ============================================================================
# voice.sh — Text Voice Renderer
# Purpose: Render text in distinct visual styles
# Usage: bash voice.sh "message" [style]
# Styles: whisper, speak, shout, corrupt, fragment, clear
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source library
source "$SCRIPT_DIR/../lib/core.sh"
source_lib style terminal text
source_theme default

# Aliases for convenience
COLS=$TERM_COLS

# Style: whisper — dim, slow, lowercase
voice_whisper() {
    local text="${1,,}"  # force lowercase
    echo ""
    printf "  ${THEME_COOL_DIM}"
    for ((i=0; i<${#text}; i++)); do
        printf "%s" "${text:$i:1}"
        sleep_ms $((40 + RANDOM % 60))
    done
    printf "${RESET}"
    echo ""
    echo ""
}

# Style: speak — standard voice, framed
voice_speak() {
    local text="$1"
    bash "$SCRIPT_DIR/manifest.sh" styled_frame "$text"
}

# Style: shout — inverted, fast, uppercase
voice_shout() {
    local text="${1^^}"  # force uppercase
    echo ""
    printf "  \033[7m${THEME_WARN}${BOLD} "
    for ((i=0; i<${#text}; i++)); do
        printf "%s" "${text:$i:1}"
        sleep_ms 15
    done
    printf " ${RESET}"
    echo ""
    echo ""
}

# Style: corrupt — text with random character swaps and glitches
voice_corrupt() {
    local text="$1"
    local glitch_chars=('░' '▒' '▓' '█' '?' '#' '@' '&' '%')
    echo ""
    printf "  ${THEME_FG}"
    for ((i=0; i<${#text}; i++)); do
        local char="${text:$i:1}"
        if [ $((RANDOM % 6)) -eq 0 ]; then
            local gc="${glitch_chars[$((RANDOM % ${#glitch_chars[@]}))]}"
            printf "${THEME_ACCENT}%s${THEME_FG}" "$gc"
            sleep_ms 80
            printf '\b'
            printf "%s" "$char"
        else
            printf "%s" "$char"
        fi
        sleep_ms $((20 + RANDOM % 30))
    done
    printf "${RESET}"
    echo ""
    echo ""
}

# Style: fragment — broken across multiple lines with random indentation
voice_fragment() {
    local text="$1"
    local words=($text)
    local fragments=()
    local current=""

    for word in "${words[@]}"; do
        current="$current $word"
        if [ $((RANDOM % 3)) -eq 0 ] || [ "${#current}" -gt 20 ]; then
            fragments+=("$current")
            current=""
        fi
    done
    [ -n "$current" ] && fragments+=("$current")

    echo ""
    for frag in "${fragments[@]}"; do
        local indent_n=$((RANDOM % 15 + 3))
        printf "%*s${THEME_FG}%s${RESET}\n" "$indent_n" "" "$frag"
        sleep_ms $((200 + RANDOM % 500))
    done
    echo ""
}

# Style: clear — no effects, centered bold text
voice_clear() {
    local text="$1"
    echo ""
    local col
    col=$(center_col "$text")
    printf "%*s${THEME_GLOW}${BOLD}%s${RESET}\n" "$col" "" "$text"
    echo ""
}

# --- Dispatch ---
style="${2:-speak}"
message="${1:-}"

if [ -z "$message" ]; then
    echo "Usage: bash voice.sh \"message\" [whisper|speak|shout|corrupt|fragment|clear]" >&2
    exit 1
fi

case "$style" in
    whisper)  voice_whisper "$message" ;;
    speak)    voice_speak "$message" ;;
    shout)    voice_shout "$message" ;;
    corrupt)  voice_corrupt "$message" ;;
    fragment) voice_fragment "$message" ;;
    clear)    voice_clear "$message" ;;
    *)        echo "Unknown voice style: $style" >&2; exit 1 ;;
esac
