# clifx-game Loop 1 — Design Spec

Status: implemented, v0.1. Written 2026-04-19.

## Why this exists

clifx is a pure-Bash terminal effects library. Rather than ship clifx as
a general library for others to use, we built a short narrative game on
top of it. The game is the forcing function: it tells us which engine
improvements matter and which don't. All four game loops (short
narrative, arcade, simulation, puzzle) are parked in
`docs/game-notes/loop-concepts.md`. This spec covers Loop 1 only.

## What it is

A single-sitting (15–25 min) narrative experience invoked as
`./clifx game`. The player runs what they think is a demo; two seconds
in, it corrupts, and an entity starts speaking through the noise.
The entity is an old navigation AI that has been drifting through
comm networks for decades and arrived at the player's terminal by
accident. Three scenes, three endings, one warm character whose
voice carries through while the clifx presentation decays around it.

## Key design decisions

### Hybrid LLM architecture

Authored scene scaffolding (keystones, mutations, exit triggers,
opening lines) plus LLM-driven character dialogue plus clifx voice
rendering. The LLM does not drive plot; it fills in the entity's
response inside a structured beat. This gives us a repeatable
emotional arc without freezing the dialogue.

### Three backends, one interface

`engine/llm.sh` exposes `llm_chat(system, transcript, user)`. Three
providers implement it with identical signatures:

- `ollama.sh` — local Ollama via `POST /api/chat` (streaming NDJSON)
- `dreamer.sh` — cloud APIs direct (Anthropic SSE or OpenAI-compat)
- `canned.sh` — 80-line bundled corpus, zero network

Auto-detection falls through Ollama health → any cloud key → canned.
The game plays on a fresh machine with no setup.

### Warm-inside-cold tone

clifx's aesthetic is naturally glitchy/dystopian. The entity is the
opposite: curious, grateful, a little frightened, never threatening.
The friction between form (decay effects) and content (warmth) is
the emotional engine. Architecture is ported from the aivia plugin
(also a terminal narrative AI game); tone is inverted.

### Diegetic enrichment with deny-by-default consent

The entity asks for environmental facts *in character*. The engine
translates each ask to a hardcoded whitelisted shell command and
runs it only on per-category consent. Three categories in v0.1:
`identity` (git config), `projects` (`ls ~/workspace`), `location`
(hostname + timezone). Security invariants:

1. Commands are keyed on category strings; LLM output cannot
   parameterize them.
2. Reason strings are display-only, never evaluated as shell.
3. Malformed ENRICH blocks silently drop.
4. Unknown categories silently drop.
5. No network reads.
6. No writes except the single preserve-ending file, which has its
   own explicit consent prompt showing the full text to be written.

These are tested in `tests/game/test_enrich_permissions.bats`,
including a shell-injection attempt that writes to `/tmp/clifx-pwned`
and verifies the marker file does *not* exist after the run.

### Cold open is the hook

`./clifx game` starts a normal-looking clifx splash for ~2 seconds,
then `chromatic_aberration` fires and the entity speaks a hardcoded
first line that makes the interruption diegetic: *"wait — don't close
this. i can see you. it's okay. it's okay."* That line is the reveal.
Everything from there is the game.

### Keystones as flat markdown + YAML

Each scene is one markdown file in `content/keystones/`. Flat
front-matter (no yq dependency) parsed by awk. Named sections for
`system_prompt`, `fallback_lines`, `exits`, `final_lines`. Exit
triggers are declarative: `<next_keystone> <field:op:value>...`,
evaluated against `state.json`. Priority goes to the first matching
trigger.

### Voice bridge layers on top of clifx

`engine/voice.sh` defines 5 entity modes (warm / whisper / fragment
/ collapse / clear) that map to clifx's native voice styles. Mode
selection is driven by `terminal.corruption_level` (grows each turn)
and `scene`. A per-line `[[mode]]` prefix overrides auto-selection.
The `entity_clear` mode is reserved — it is the single un-decorated
line at the ending.

## Architecture at a glance

```
./clifx game
      ↓
cold_open → state_init → apply(awakening)
      ↓
┌─ main loop ──────────────────────────────────────────────┐
│ entity line (opening on turn 1, else llm_chat)           │
│   ↳ parse ENRICH? → permissions_prompt → enrich_run     │
│   ↳ strip block, render via voice_bridge                 │
│ read player input                                        │
│ parser_stance (LLM or keyword) → state.player.stance    │
│ state_inc message_count, check_exits                     │
│ if next is ending-* → render_ending (authored) → exit   │
│ if next is dialogue → apply mutations, continue          │
└──────────────────────────────────────────────────────────┘
      ↓
state dump → var/transcript-<ts>.log
```

All engine modules shell out to each other (state.sh, scene.sh,
enrich.sh, permissions.sh, parser.sh) except voice.sh which is
sourced by `clifx-game` to avoid re-loading clifx per line.

## Testing

111 bats tests covering every engine module. The full suite runs
headless with no network, no API keys, no Ollama. Live tests for
Ollama and Anthropic skip cleanly when those backends are not
reachable. Security-oriented tests exercise shell-injection
resistance, deny-by-default parsing, and whitelist enforcement.

## What v0.1 deliberately excludes

- Save/resume within a session (the game is a single sitting)
- Network enrichment (IP geolocation, weather, GitHub API) —
  deferred to v0.2 with the same consent pattern
- The other three game loops (arcade / simulation / puzzle) —
  each will reuse the state machine + scene loader but require
  additional engine work (real-time input loop, save format)
- Cross-run progression or unlocks

## How to extend

**Add a keystone (new dialogue beat):** drop a markdown file in
`content/keystones/`. The TUI-less scene loader auto-discovers.
Front-matter must include `id`; everything else is optional. Update
the previous keystone's `exits` to point to it.

**Add an enrichment category (v0.2):** edit `engine/enrich.sh` —
extend the `_enrich_command_for`, `_enrich_description_for`, and
`enrich_is_valid_category` case blocks. Add a spec file in
`content/enrichment/<name>.md` for documentation. Do *not* put the
shell command in the content file.

**Add a provider:** drop a script in `engine/providers/<name>.sh`
that defines `provider_chat` with the `(system, transcript, user)`
signature. Register in `llm.sh`'s `_llm_resolve_provider` allowlist
and update auto-detect if needed.

## Reuse from external projects

- aivia (`~/projects/aivia` on dreamer) — state.sh pattern, voice
  style architecture, phase+keystone+message-threshold pacing.
  Tonally inverted (cold-manipulative → warm-fading); architecture
  preserved.
- geepers-chat-demo — confirmed the Ollama `curl + jq` pattern and
  OpenAI-compat streaming shape. No code lifted directly; the
  Bash reimplementation is ~60 lines per provider.

## Known limits

- Canned corpus is 80 lines. Repeats visibly after 2–3 turns.
  Intentional — it is a fallback, not the primary experience.
- Enrichment is never exercised with the canned provider (canned
  responses don't emit ENRICH blocks). Live LLMs exercise the full
  consent pipeline.
- The `release` ending's authored timing is fixed; no way to skip.

Full plan and detailed phase sequence:
`~/.claude/plans/refactored-crafting-whale.md`.
