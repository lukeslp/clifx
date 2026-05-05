#!/usr/bin/env bash
# ============================================================================
# game/engine/scene.sh — keystone loader + scene state machine
# Parses keystone markdown files (flat YAML front-matter + named sections),
# applies state mutations, evaluates exit triggers against state.json.
#
# Keystone format:
#   ---
#   id: awakening
#   phase: 1
#   trigger_message_threshold: 0
#   state_mutations: entity.phase=1 terminal.corruption_level=0.15
#   allowed_enrichment: identity
#   opening_mode: entity_whisper
#   opening_line: wait — don't close this. i can see you.
#   ---
#   ## system_prompt
#   <paragraph>
#   ## fallback_lines
#   <one line per fallback>
#   ## exits
#   <next_keystone> <field:op:value> [field:op:value]...
# ============================================================================

_SCENE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_SCENE_CONTENT_DIR="${CLIFX_GAME_KEYSTONES:-$_SCENE_DIR/../content/keystones}"
_SCENE_STATE_SH="${CLIFX_GAME_STATE_SH:-$_SCENE_DIR/state.sh}"

_scene_path() {
    local id="${1:?usage: <keystone_id>}"
    local p="$_SCENE_CONTENT_DIR/${id}.md"
    [ -f "$p" ] || { echo "scene.sh: keystone not found: $p" >&2; return 1; }
    echo "$p"
}

# List available keystones (basename without .md extension).
scene_list() {
    [ -d "$_SCENE_CONTENT_DIR" ] || return 1
    local f
    for f in "$_SCENE_CONTENT_DIR"/*.md; do
        [ -e "$f" ] || continue
        basename "$f" .md
    done
}

# Extract a front-matter field. Prints the value with leading/trailing
# whitespace trimmed. Empty output if not present.
scene_get_field() {
    local id="${1:?usage: scene_get_field <id> <field>}"
    local field="${2:?}"
    local path; path=$(_scene_path "$id") || return 1
    awk -v field="$field" '
        /^---$/ { fm = !fm; next }
        fm && $0 ~ "^[[:space:]]*"field"[[:space:]]*:[[:space:]]*" {
            sub("^[[:space:]]*"field"[[:space:]]*:[[:space:]]*", "")
            sub("[[:space:]]+$", "")
            print
            exit
        }
    ' "$path"
}

# Extract a named markdown section body. Section headers use `## name`.
# Body extends until the next `## ` header or EOF.
scene_get_section() {
    local id="${1:?usage: scene_get_section <id> <section>}"
    local section="${2:?}"
    local path; path=$(_scene_path "$id") || return 1
    awk -v sec="$section" '
        /^---$/ { fm = !fm; next }
        fm { next }
        /^## / {
            name = substr($0, 4)
            sub("[[:space:]]+$", "", name)
            in_section = (name == sec)
            next
        }
        in_section { print }
    ' "$path"
}

# Apply the keystone state_mutations field to state.json. Each mutation
# is `key=value` space-separated. Values go through state_set which
# attempts JSON parse first.
scene_apply_mutations() {
    local id="${1:?usage: scene_apply_mutations <id>}"
    local mutations; mutations=$(scene_get_field "$id" state_mutations)
    [ -z "$mutations" ] && return 0

    local pair key value
    for pair in $mutations; do
        key="${pair%%=*}"
        value="${pair#*=}"
        bash "$_SCENE_STATE_SH" set "$key" "$value" >/dev/null
    done
    # Always set the scene field to this keystone's id
    bash "$_SCENE_STATE_SH" set scene "\"$id\"" >/dev/null
}

# Evaluate a single condition of shape field:op:value against current state.
# Numeric comparisons happen with awk (handles floats). Strings are direct.
_scene_eval_condition() {
    local cond="$1"
    local field op expected actual
    field="${cond%%:*}";   cond="${cond#*:}"
    op="${cond%%:*}";      expected="${cond#*:}"

    actual=$(bash "$_SCENE_STATE_SH" get "$field" 2>/dev/null)
    [ "$actual" = "null" ] && actual=""

    case "$op" in
        eq) [ "$actual" = "$expected" ] ;;
        ne) [ "$actual" != "$expected" ] ;;
        ge) awk "BEGIN{exit !($actual >= $expected)}" ;;
        gt) awk "BEGIN{exit !($actual >  $expected)}" ;;
        le) awk "BEGIN{exit !($actual <= $expected)}" ;;
        lt) awk "BEGIN{exit !($actual <  $expected)}" ;;
        *)  return 1 ;;
    esac
}

# Check exit triggers for <id>. Prints the first matching next-keystone id
# (and returns 0), or empty output with return 1 if no exit triggers match.
scene_check_exits() {
    local id="${1:?usage: scene_check_exits <id>}"
    local exits; exits=$(scene_get_section "$id" exits)
    [ -z "$exits" ] && return 1

    local line next conditions cond
    while IFS= read -r line; do
        # Trim
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [ -z "$line" ] && continue
        # First token is the target keystone; rest are conditions
        next="${line%% *}"
        conditions="${line#$next}"
        conditions="${conditions# }"

        local all_match=1
        if [ -n "$conditions" ]; then
            for cond in $conditions; do
                if ! _scene_eval_condition "$cond"; then
                    all_match=0
                    break
                fi
            done
        fi

        if [ "$all_match" -eq 1 ]; then
            echo "$next"
            return 0
        fi
    done <<< "$exits"
    return 1
}

# Opening-line convenience: print the authored first line with its mode
# prefix so entity_speak picks it up.
scene_opening_line() {
    local id="${1:?usage: scene_opening_line <id>}"
    local mode line
    mode=$(scene_get_field "$id" opening_mode)
    line=$(scene_get_field "$id" opening_line)
    [ -z "$line" ] && return 1
    if [ -n "$mode" ]; then
        echo "[[${mode}]] ${line}"
    else
        echo "$line"
    fi
}

# CLI dispatch
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    cmd="${1:-list}"
    shift || true
    case "$cmd" in
        list)        scene_list ;;
        field)       scene_get_field "$@" ;;
        section)     scene_get_section "$@" ;;
        apply)       scene_apply_mutations "$@" ;;
        check_exits) scene_check_exits "$@" ;;
        opening)     scene_opening_line "$@" ;;
        help|*)
            cat <<HELP
scene.sh — clifx-game keystone loader

Usage:
  scene.sh list                       list available keystones
  scene.sh field <id> <name>          read a front-matter field
  scene.sh section <id> <name>        read a named ## section body
  scene.sh apply <id>                 apply the keystone's state_mutations
  scene.sh check_exits <id>           print next keystone if a trigger fires
  scene.sh opening <id>               print the authored opening line

Env:
  CLIFX_GAME_KEYSTONES    override content/keystones directory
HELP
            ;;
    esac
fi
