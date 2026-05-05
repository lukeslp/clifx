#!/usr/bin/env bash
# ============================================================================
# game/engine/permissions.sh — in-character consent for enrichment reads
# Session-level memory stored in var/permissions.json. Three states per
# category: unset (ask every time), "always" (auto-allow), "never" (auto-deny).
# The consent UI is deliberately un-styled so it's visually distinct from
# entity dialogue — players always know when a real read is about to happen.
# ============================================================================

_PERMS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_PERMS_FILE="${CLIFX_GAME_PERMS_FILE:-$_PERMS_DIR/../var/permissions.json}"
_PERMS_ENRICH_SH="$_PERMS_DIR/enrich.sh"

_perms_require_jq() {
    command -v jq >/dev/null 2>&1 || { echo "permissions.sh: jq required" >&2; return 1; }
}

# Initialize or reset the permissions store (empty object).
permissions_init() {
    _perms_require_jq || return 1
    mkdir -p "$(dirname "$_PERMS_FILE")"
    echo '{}' > "$_PERMS_FILE"
}

# Ensure the file exists; create if missing.
_perms_ensure() {
    [ -f "$_PERMS_FILE" ] || permissions_init
}

# Get stored state for a category. Echoes "always" | "never" | "unset".
permissions_get() {
    _perms_ensure
    local category="${1:?usage: permissions_get <category>}"
    local value
    value=$(jq -r --arg c "$category" '.[$c] // "unset"' "$_PERMS_FILE")
    echo "$value"
}

# Persist a decision for a category. Only "always" and "never" are stored
# (one-shot y/n don't persist).
permissions_set() {
    _perms_ensure
    _perms_require_jq || return 1
    local category="${1:?}" choice="${2:?}"
    case "$choice" in
        always|never) ;;
        *) echo "permissions.sh: invalid choice '$choice' (expected always|never)" >&2; return 1 ;;
    esac
    local tmp; tmp=$(mktemp)
    jq --arg c "$category" --arg v "$choice" '.[$c] = $v' \
        "$_PERMS_FILE" > "$tmp"
    mv "$tmp" "$_PERMS_FILE"
}

# Clear all persisted decisions for a fresh session.
permissions_clear() {
    rm -f "$_PERMS_FILE"
}

# Interactive consent prompt. Echoes "allow" or "deny" to stdout.
# Inputs: category (required), reason (optional, shown as the entity's ask).
# Responses:
#   y            → allow once
#   n (empty)    → deny once
#   always       → allow this session and persist
#   never        → deny this session and persist
# If a category is already set to always/never, skip the prompt.
permissions_prompt() {
    local category="${1:?usage: permissions_prompt <category> [reason]}"
    local reason="${2-}"

    # Short-circuit on persisted decision
    local stored; stored=$(permissions_get "$category")
    case "$stored" in
        always) echo "allow"; return 0 ;;
        never)  echo "deny";  return 0 ;;
    esac

    local description
    description=$(bash "$_PERMS_ENRICH_SH" describe "$category" 2>/dev/null \
        || echo "(unknown category)")

    # Print the consent UI to stderr so stdout stays clean for the response.
    {
        echo ""
        echo "  ----- the entity is reaching out -----"
        echo "  it wants: $description"
        if [ -n "$reason" ]; then
            echo "  its reason: \"$reason\""
        fi
        echo "  allow? (y/n/always/never)"
        echo ""
    } >&2

    local reply
    if [ -n "${CLIFX_GAME_PERMS_ANSWER:-}" ]; then
        # Test / scripted override: e.g. CLIFX_GAME_PERMS_ANSWER=y
        reply="$CLIFX_GAME_PERMS_ANSWER"
    else
        read -r -p "  > " reply || reply=""
    fi

    case "${reply,,}" in
        y|yes)   echo "allow" ;;
        always)  permissions_set "$category" always; echo "allow" ;;
        never)   permissions_set "$category" never;  echo "deny" ;;
        *)       echo "deny" ;;
    esac
}

# Full consent-and-run flow. Given a category + reason, runs the permission
# prompt; on allow, runs the whitelisted enrichment and records the result;
# on deny, marks the category as declined. Returns 0 if allowed + run, 1 on
# deny, 2 on invalid category.
permissions_request_enrichment() {
    local category="${1:?usage: permissions_request_enrichment <category> [reason]}"
    local reason="${2-}"

    bash "$_PERMS_ENRICH_SH" categories | grep -qx "$category" || return 2

    local decision; decision=$(permissions_prompt "$category" "$reason")
    if [ "$decision" = "allow" ]; then
        local result
        result=$(bash "$_PERMS_ENRICH_SH" run "$category")
        # Use jq to JSON-encode the string so special chars don't break state_set
        local quoted
        quoted=$(printf '%s' "$result" | jq -Rs .)
        bash "$_PERMS_ENRICH_SH" record "$category" "$quoted" >/dev/null
        echo "$result"
        return 0
    else
        bash "$_PERMS_ENRICH_SH" decline "$category" >/dev/null
        return 1
    fi
}

# CLI dispatch
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    cmd="${1:-help}"
    shift || true
    case "$cmd" in
        init)    permissions_init ;;
        get)     permissions_get "$@" ;;
        set)     permissions_set "$@" ;;
        prompt)  permissions_prompt "$@" ;;
        request) permissions_request_enrichment "$@" ;;
        clear)   permissions_clear ;;
        help|*)
            cat <<HELP
permissions.sh — clifx-game consent engine

Usage:
  permissions.sh init
  permissions.sh get <category>
  permissions.sh set <category> <always|never>
  permissions.sh prompt <category> [reason]     interactive consent, echo allow/deny
  permissions.sh request <category> [reason]    prompt + run + record in one go
  permissions.sh clear                          wipe session memory

Env:
  CLIFX_GAME_PERMS_FILE    override permissions.json path
  CLIFX_GAME_PERMS_ANSWER  test override: y | n | always | never
HELP
            ;;
    esac
fi
