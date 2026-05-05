#!/usr/bin/env bash
# ============================================================================
# game/engine/enrich.sh — whitelisted environmental enrichment
# The LLM asks for a fact by category (in character). The engine runs the
# hardcoded shell command associated with that category, IF the player has
# consented (handled by permissions.sh). LLM output never parameterizes the
# command — the reason is a display-only string.
#
# v0.1 categories (security invariant — extend only by editing this file):
#   identity   — git config user.name + email
#   projects   — ls ~/workspace (names only, top 20)
#   location   — hostname + timezone
# ============================================================================

_ENRICH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_ENRICH_STATE_SH="${CLIFX_GAME_STATE_SH:-$_ENRICH_DIR/state.sh}"

# Hardcoded command whitelist. KEY → single shell command. Never evaluated
# with LLM-provided arguments.
_enrich_command_for() {
    case "$1" in
        identity)
            local name email
            name=$(git config user.name 2>/dev/null || echo "")
            email=$(git config user.email 2>/dev/null || echo "")
            if [ -n "$name" ] && [ -n "$email" ]; then
                printf '%s (%s)' "$name" "$email"
            elif [ -n "$name" ]; then
                printf '%s' "$name"
            else
                printf 'unknown'
            fi
            ;;
        projects)
            local home="${HOME:-/home/$(whoami)}"
            local dir="${CLIFX_GAME_PROJECTS_DIR:-$home/workspace}"
            if [ -d "$dir" ]; then
                ls -1 "$dir" 2>/dev/null \
                    | grep -v '^node_modules$\|^\.\|^dist$\|^venv$\|^__pycache__$' \
                    | head -20 \
                    | tr '\n' ',' \
                    | sed 's/,$//; s/,/, /g'
            else
                printf '(none)'
            fi
            ;;
        location)
            local host tz
            host=$(hostname 2>/dev/null || echo "unknown-host")
            tz=$(date +%Z 2>/dev/null || echo "")
            if [ -n "$tz" ]; then
                printf '%s in timezone %s' "$host" "$tz"
            else
                printf '%s' "$host"
            fi
            ;;
        *)
            return 1
            ;;
    esac
}

# Human-readable description of a category (shown to player in consent UI).
_enrich_description_for() {
    case "$1" in
        identity) echo "your git identity (name + email from ~/.gitconfig)" ;;
        projects) echo "names of directories in ~/workspace" ;;
        location) echo "your machine's hostname and timezone" ;;
        *) return 1 ;;
    esac
}

# List available categories (names only).
enrich_available_categories() {
    printf 'identity\nprojects\nlocation\n'
}

# Is the given category in the whitelist?
enrich_is_valid_category() {
    case "$1" in
        identity|projects|location) return 0 ;;
        *) return 1 ;;
    esac
}

# Return a human-readable description for player display.
enrich_describe() {
    local category="${1:?usage: enrich_describe <category>}"
    enrich_is_valid_category "$category" || return 1
    _enrich_description_for "$category"
}

# Run the whitelisted command for a category. Prints the result to stdout.
# Returns nonzero if category is unknown. Caller is responsible for
# permission-checking before invoking.
enrich_run() {
    local category="${1:?usage: enrich_run <category>}"
    enrich_is_valid_category "$category" || return 1
    _enrich_command_for "$category"
}

# Parse an LLM response for a trailing <<ENRICH>>{...}<<END>> block.
# On success, prints the JSON object to stdout. On missing/malformed block,
# prints nothing and returns 1. Deny-by-default: any parse failure is silent.
enrich_parse_response() {
    local text="${1-}"
    # Extract the JSON block (greedy-safe: last ENRICH block wins if duplicates)
    local block
    block=$(printf '%s' "$text" \
        | awk 'BEGIN{RS="<<END>>"} /<<ENRICH>>/ {sub(/.*<<ENRICH>>/, ""); print}' \
        | tail -n 1)
    [ -z "$block" ] && return 1

    # Validate as JSON and extract .ask + .reason
    local ask reason
    ask=$(printf '%s' "$block" | jq -er '.ask // empty' 2>/dev/null)
    reason=$(printf '%s' "$block" | jq -er '.reason // empty' 2>/dev/null)
    [ -z "$ask" ] && return 1
    enrich_is_valid_category "$ask" || return 1

    # Emit the validated JSON (reason may be empty; pass it along)
    jq -n --arg ask "$ask" --arg reason "$reason" '{ask: $ask, reason: $reason}'
}

# Strip the enrichment block from the text (returns cleaned text so it can
# be rendered without the trailing tag).
enrich_strip_block() {
    local text="${1-}"
    # Remove everything between <<ENRICH>> and <<END>> inclusive
    printf '%s' "$text" | perl -0777 -pe 's/\s*<<ENRICH>>.*?<<END>>\s*//sg' 2>/dev/null \
        || printf '%s' "$text" | awk '
            BEGIN { keep = 1 }
            { gsub(/[[:space:]]*<<ENRICH>>.*<<END>>[[:space:]]*/, ""); print }
        '
}

# Write an enrichment result into state.json at enrichment.<category>.
# The caller (permissions.sh / main loop) uses this after a successful
# consented run.
enrich_record() {
    local category="${1:?usage: enrich_record <category> <value>}"
    local value="${2-}"
    enrich_is_valid_category "$category" || return 1
    bash "$_ENRICH_STATE_SH" set "enrichment.$category" "$value"
}

# Mark a category as declined (player said no). Stored as the literal
# string "declined" so downstream code can distinguish null (untouched),
# "declined" (refused), and other strings (granted + result).
enrich_decline() {
    local category="${1:?usage: enrich_decline <category>}"
    enrich_is_valid_category "$category" || return 1
    bash "$_ENRICH_STATE_SH" set "enrichment.$category" "\"declined\""
}

# CLI dispatch
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    cmd="${1:-help}"
    shift || true
    case "$cmd" in
        categories) enrich_available_categories ;;
        describe)   enrich_describe "$@" ;;
        run)        enrich_run "$@" ;;
        parse)      enrich_parse_response "$@" ;;
        strip)      enrich_strip_block "$@" ;;
        record)     enrich_record "$@" ;;
        decline)    enrich_decline "$@" ;;
        help|*)
            cat <<HELP
enrich.sh — clifx-game environmental enrichment

Usage:
  enrich.sh categories                list whitelisted categories
  enrich.sh describe <cat>            human description of a category
  enrich.sh run <cat>                 run the whitelisted read (no consent check)
  enrich.sh parse <llm_response>      extract <<ENRICH>>{...}<<END>> JSON
  enrich.sh strip <llm_response>      remove the ENRICH block from text
  enrich.sh record <cat> <value>      write result into state.enrichment
  enrich.sh decline <cat>             mark category as declined

Whitelist is hardcoded. LLM output cannot parameterize any command.
HELP
            ;;
    esac
fi
