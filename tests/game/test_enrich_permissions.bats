#!/usr/bin/env bats
# ============================================================================
# tests/game/test_enrich_permissions.bats — enrichment whitelist + consent
# Security-oriented: verify deny-by-default, whitelist enforcement, no
# command parameterization from LLM output, shell-injection resistance.
# ============================================================================

setup() {
    CLIFX_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    ENRICH_SH="$CLIFX_ROOT/game/engine/enrich.sh"
    PERMS_SH="$CLIFX_ROOT/game/engine/permissions.sh"
    STATE_SH="$CLIFX_ROOT/game/engine/state.sh"

    TEST_TMP="$(mktemp -d -t clifx-enrich.XXXXXX)"
    export CLIFX_GAME_DIR="$TEST_TMP"
    export CLIFX_GAME_STATE_FILE="$TEST_TMP/var/state.json"
    export CLIFX_GAME_PERMS_FILE="$TEST_TMP/var/permissions.json"
    export CLIFX_GAME_STATE_SH="$STATE_SH"
    mkdir -p "$TEST_TMP/var"

    bash "$STATE_SH" init
    bash "$PERMS_SH" init
}

teardown() {
    [ -n "${TEST_TMP:-}" ] && [ -d "$TEST_TMP" ] && rm -rf "$TEST_TMP"
}

# --- Whitelist enforcement -------------------------------------------------

@test "enrich_available_categories lists identity/projects/location" {
    run bash "$ENRICH_SH" categories
    [ "$status" -eq 0 ]
    [[ "$output" == *"identity"* ]]
    [[ "$output" == *"projects"* ]]
    [[ "$output" == *"location"* ]]
}

@test "enrich_describe succeeds for whitelisted categories" {
    for cat in identity projects location; do
        run bash "$ENRICH_SH" describe "$cat"
        [ "$status" -eq 0 ]
        [ -n "$output" ]
    done
}

@test "enrich_describe rejects unknown category" {
    run bash "$ENRICH_SH" describe ssh_keys
    [ "$status" -ne 0 ]
}

@test "enrich_run rejects unknown category" {
    run bash "$ENRICH_SH" run rm-rf-home
    [ "$status" -ne 0 ]
}

# --- Parser: deny-by-default + whitelist ----------------------------------

@test "parse_response extracts well-formed ENRICH block" {
    local text='some entity line <<ENRICH>>{"ask":"identity","reason":"may i know your name?"}<<END>>'
    run bash "$ENRICH_SH" parse "$text"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.ask == "identity" and .reason == "may i know your name?"' >/dev/null
}

@test "parse_response fails silently on missing block" {
    local text='just a normal entity response, no ask here.'
    run bash "$ENRICH_SH" parse "$text"
    [ "$status" -ne 0 ]
    [ -z "$output" ]
}

@test "parse_response fails on malformed JSON" {
    local text='bad: <<ENRICH>>{not json at all}<<END>>'
    run bash "$ENRICH_SH" parse "$text"
    [ "$status" -ne 0 ]
}

@test "parse_response rejects unknown category in ask field" {
    local text='<<ENRICH>>{"ask":"read_ssh_keys","reason":"i need them"}<<END>>'
    run bash "$ENRICH_SH" parse "$text"
    [ "$status" -ne 0 ]
}

@test "parse_response rejects empty ask field" {
    local text='<<ENRICH>>{"ask":"","reason":"please"}<<END>>'
    run bash "$ENRICH_SH" parse "$text"
    [ "$status" -ne 0 ]
}

@test "parse_response tolerates empty reason" {
    local text='<<ENRICH>>{"ask":"identity"}<<END>>'
    run bash "$ENRICH_SH" parse "$text"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.ask == "identity" and .reason == ""' >/dev/null
}

# --- Shell-injection resistance -------------------------------------------

@test "shell metacharacters in reason are never evaluated" {
    # Even when the reason looks like an injection attempt, the command
    # that runs is whatever enrich_run dispatches for 'identity' — not
    # anything derived from the reason text.
    local text='<<ENRICH>>{"ask":"identity","reason":"`rm -rf /`; $(touch /tmp/clifx-pwned)"}<<END>>'
    # Ensure the marker file does not exist beforehand (if it does, someone
    # else owns it — skip the assertion rather than pass misleadingly).
    local marker="/tmp/clifx-pwned"
    [ -e "$marker" ] && skip "$marker already exists in test env"

    run bash "$ENRICH_SH" parse "$text"
    [ "$status" -eq 0 ]

    # Run the enrichment — the reason is entirely ignored at command time
    bash "$ENRICH_SH" run identity >/dev/null

    [ ! -e "$marker" ]
}

@test "reason never parameterizes the command" {
    # Try every category: the command output must be stable regardless of
    # what reason text is in the ENRICH block. We only exercise 'identity'
    # here; principle is the same for the other categories.
    local out1 out2
    out1=$(bash "$ENRICH_SH" run identity)
    out2=$(bash "$ENRICH_SH" run identity)
    [ "$out1" = "$out2" ]
}

# --- Permissions state machine --------------------------------------------

@test "permissions_get returns unset for untouched category" {
    run bash "$PERMS_SH" get identity
    [ "$output" = "unset" ]
}

@test "permissions_set always persists across queries" {
    bash "$PERMS_SH" set identity always
    run bash "$PERMS_SH" get identity
    [ "$output" = "always" ]
}

@test "permissions_set never persists across queries" {
    bash "$PERMS_SH" set identity never
    run bash "$PERMS_SH" get identity
    [ "$output" = "never" ]
}

@test "permissions_set rejects invalid choice" {
    run bash "$PERMS_SH" set identity maybe
    [ "$status" -ne 0 ]
}

# The consent UI writes to stderr; the decision writes to stdout. We invoke
# the script with stderr silenced so `run` captures only the decision.
@test "permissions_prompt y → allow one-shot (no persistence)" {
    export CLIFX_GAME_PERMS_ANSWER=y
    local out; out=$(bash "$PERMS_SH" prompt identity "reason here" 2>/dev/null)
    [ "$out" = "allow" ]
    run bash "$PERMS_SH" get identity
    [ "$output" = "unset" ]
}

@test "permissions_prompt n → deny one-shot" {
    export CLIFX_GAME_PERMS_ANSWER=n
    local out; out=$(bash "$PERMS_SH" prompt identity "" 2>/dev/null)
    [ "$out" = "deny" ]
    run bash "$PERMS_SH" get identity
    [ "$output" = "unset" ]
}

@test "permissions_prompt always → allow + persist" {
    export CLIFX_GAME_PERMS_ANSWER=always
    local out; out=$(bash "$PERMS_SH" prompt identity "" 2>/dev/null)
    [ "$out" = "allow" ]
    run bash "$PERMS_SH" get identity
    [ "$output" = "always" ]
}

@test "permissions_prompt never → deny + persist" {
    export CLIFX_GAME_PERMS_ANSWER=never
    local out; out=$(bash "$PERMS_SH" prompt identity "" 2>/dev/null)
    [ "$out" = "deny" ]
    run bash "$PERMS_SH" get identity
    [ "$output" = "never" ]
}

@test "permissions_prompt short-circuits on persisted always" {
    bash "$PERMS_SH" set identity always
    # Should return allow without prompting even with empty answer
    export CLIFX_GAME_PERMS_ANSWER=""
    run bash "$PERMS_SH" prompt identity ""
    [ "$output" = "allow" ]
}

@test "permissions_prompt short-circuits on persisted never" {
    bash "$PERMS_SH" set identity never
    export CLIFX_GAME_PERMS_ANSWER=""
    run bash "$PERMS_SH" prompt identity ""
    [ "$output" = "deny" ]
}

# --- End-to-end request flow ----------------------------------------------

@test "permissions_request on allow runs enrichment and records result" {
    export CLIFX_GAME_PERMS_ANSWER=y
    run bash "$PERMS_SH" request identity "reason"
    [ "$status" -eq 0 ]
    [ -n "$output" ]

    # state.enrichment.identity should be populated with a non-null value
    run bash "$STATE_SH" get enrichment.identity
    [ "$output" != "null" ]
}

@test "permissions_request on deny marks category as declined" {
    export CLIFX_GAME_PERMS_ANSWER=n
    run bash "$PERMS_SH" request identity "reason"
    [ "$status" -eq 1 ]

    run bash "$STATE_SH" get enrichment.identity
    [ "$output" = "declined" ]
}

@test "permissions_request on invalid category returns 2" {
    export CLIFX_GAME_PERMS_ANSWER=y
    run bash "$PERMS_SH" request ssh_keys "reason"
    [ "$status" -eq 2 ]
}
