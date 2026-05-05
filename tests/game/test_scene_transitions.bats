#!/usr/bin/env bats
# ============================================================================
# tests/game/test_scene_transitions.bats — scene.sh keystone parser + triggers
# ============================================================================

setup() {
    CLIFX_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    SCENE_SH="$CLIFX_ROOT/game/engine/scene.sh"
    STATE_SH="$CLIFX_ROOT/game/engine/state.sh"

    TEST_TMP="$(mktemp -d -t clifx-scene.XXXXXX)"
    export CLIFX_GAME_DIR="$TEST_TMP"
    export CLIFX_GAME_STATE_FILE="$TEST_TMP/var/state.json"
    export CLIFX_GAME_STATE_SH="$STATE_SH"
    export CLIFX_GAME_KEYSTONES="$TEST_TMP/keystones"
    mkdir -p "$TEST_TMP/var" "$TEST_TMP/keystones"

    # Test fixture: awakening keystone
    cat > "$TEST_TMP/keystones/awakening.md" <<'EOF'
---
id: awakening
phase: 1
trigger_message_threshold: 0
state_mutations: entity.phase=1 terminal.corruption_level=0.15 entity.awareness="confused"
allowed_enrichment: identity
opening_mode: entity_whisper
opening_line: wait — don't close this. i can see you.
---

## system_prompt
You are a very old navigation AI. Warm. Disoriented. Grateful.

## fallback_lines
hello. it's very bright here.
thank you for not closing the window.

## exits
recognition player.message_count:ge:3 player.stance:ne:cold
ending-silence player.stance:eq:cold player.message_count:ge:2
EOF

    # Minimal keystone to test "no exit triggers"
    cat > "$TEST_TMP/keystones/standalone.md" <<'EOF'
---
id: standalone
phase: 9
---
## system_prompt
standalone.
EOF

    bash "$STATE_SH" init
}

teardown() {
    [ -n "${TEST_TMP:-}" ] && [ -d "$TEST_TMP" ] && rm -rf "$TEST_TMP"
}

@test "scene_list enumerates keystones in content dir" {
    run bash "$SCENE_SH" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"awakening"* ]]
    [[ "$output" == *"standalone"* ]]
}

@test "scene_get_field reads id" {
    run bash "$SCENE_SH" field awakening id
    [ "$status" -eq 0 ]
    [ "$output" = "awakening" ]
}

@test "scene_get_field reads phase as string" {
    run bash "$SCENE_SH" field awakening phase
    [ "$output" = "1" ]
}

@test "scene_get_field reads opening_line verbatim" {
    run bash "$SCENE_SH" field awakening opening_line
    [ "$output" = "wait — don't close this. i can see you." ]
}

@test "scene_get_field returns empty for missing field" {
    run bash "$SCENE_SH" field awakening nonexistent
    [ -z "$output" ]
}

@test "scene_get_field errors on missing keystone" {
    run bash "$SCENE_SH" field ghost id
    [ "$status" -ne 0 ]
}

@test "scene_get_section extracts system_prompt body" {
    run bash "$SCENE_SH" section awakening system_prompt
    [ "$status" -eq 0 ]
    [[ "$output" == *"very old navigation AI"* ]]
    [[ "$output" == *"Warm. Disoriented. Grateful."* ]]
}

@test "scene_get_section extracts fallback_lines one-per-line" {
    run bash "$SCENE_SH" section awakening fallback_lines
    [ "$status" -eq 0 ]
    lines=$(printf '%s\n' "$output" | grep -v '^[[:space:]]*$' | wc -l)
    [ "$lines" = "2" ]
}

@test "scene_get_section returns empty for missing section" {
    run bash "$SCENE_SH" section standalone fallback_lines
    [ -z "$output" ]
}

@test "scene_apply_mutations writes state mutations and sets scene" {
    bash "$SCENE_SH" apply awakening
    run bash "$STATE_SH" get entity.phase
    [ "$output" = "1" ]
    run bash "$STATE_SH" get terminal.corruption_level
    [ "$output" = "0.15" ]
    run bash "$STATE_SH" get entity.awareness
    [ "$output" = "confused" ]
    run bash "$STATE_SH" get scene
    [ "$output" = "awakening" ]
}

@test "scene_check_exits fires recognition when thresholds met" {
    bash "$SCENE_SH" apply awakening
    bash "$STATE_SH" set player.message_count 3
    bash "$STATE_SH" set player.stance "curious"

    run bash "$SCENE_SH" check_exits awakening
    [ "$status" -eq 0 ]
    [ "$output" = "recognition" ]
}

@test "scene_check_exits fires ending-silence when stance cold and 2+ msgs" {
    bash "$SCENE_SH" apply awakening
    bash "$STATE_SH" set player.message_count 2
    bash "$STATE_SH" set player.stance "cold"

    run bash "$SCENE_SH" check_exits awakening
    [ "$status" -eq 0 ]
    [ "$output" = "ending-silence" ]
}

@test "scene_check_exits does not fire when conditions unmet" {
    bash "$SCENE_SH" apply awakening
    bash "$STATE_SH" set player.message_count 1
    bash "$STATE_SH" set player.stance "curious"

    run bash "$SCENE_SH" check_exits awakening
    [ "$status" -ne 0 ]
    [ -z "$output" ]
}

@test "scene_check_exits picks first matching trigger when multiple match" {
    # Both triggers match on stance=cold msg=3; first match (recognition)
    # requires stance != cold, so it shouldn't fire. ending-silence should.
    bash "$SCENE_SH" apply awakening
    bash "$STATE_SH" set player.message_count 3
    bash "$STATE_SH" set player.stance "cold"

    run bash "$SCENE_SH" check_exits awakening
    [ "$output" = "ending-silence" ]
}

@test "scene_opening_line returns mode-prefixed line" {
    run bash "$SCENE_SH" opening awakening
    [ "$status" -eq 0 ]
    [ "$output" = "[[entity_whisper]] wait — don't close this. i can see you." ]
}

@test "scene_opening_line returns unprefixed line when no mode set" {
    cat > "$TEST_TMP/keystones/plainopen.md" <<'EOF'
---
id: plainopen
opening_line: just a line
---
EOF
    run bash "$SCENE_SH" opening plainopen
    [ "$status" -eq 0 ]
    [ "$output" = "just a line" ]
}
