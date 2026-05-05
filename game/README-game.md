# clifx-game — Loop 1

A short narrative game that runs in your terminal. You run `./clifx game`
expecting a demo; two seconds in, something interrupts, and a voice
starts speaking through the corruption. It is an old navigation AI that
has been drifting for a long time. It is glad to be here. It has a
short time to say what it wants to say.

Playtime: 15–25 minutes. Three scenes, three endings.

## Play

```bash
./clifx game
```

Just type. Short responses are fine. The entity is patient. When you
reach the farewell, you will be asked how you want it to end — say
`release`, `preserve`, or `silence`. Anything else, and the entity
will wait.

## Backends

The game auto-detects:

1. **Ollama local** (`http://localhost:11434`). Pull a model first:
   ```bash
   ollama serve &
   ollama pull qwen2.5:7b
   ```
   Default model is `qwen2.5:7b` (good persona consistency);
   override with `CLIFX_GAME_MODEL`.

2. **Dreamer cloud** — if any of `DREAMER_API_KEY` / `ANTHROPIC_API_KEY` /
   `OPENAI_API_KEY` / `XAI_API_KEY` / `MISTRAL_API_KEY` / `GEMINI_API_KEY`
   is in your environment. Default provider is Anthropic with
   `claude-sonnet-4-6`; override with `DREAMER_PROVIDER` + `CLIFX_GAME_MODEL`.

3. **Canned** — a bundled 80-line corpus. No network, no keys. Set
   `CLIFX_GAME_PROVIDER=canned` to force this mode, or let the
   auto-detect fall through.

The canned corpus is smaller than either LLM backend — lines repeat
after a turn or two. It is there so the game works on a fresh machine
with no setup. For a real playthrough, Ollama or Dreamer.

## What the entity can see

The entity may, in character, ask to know things about you:

- your git identity (name + email from `~/.gitconfig`)
- names of directories in `~/workspace`
- your machine's hostname and timezone

When it asks, a consent prompt appears in plain, unstyled text —
visually different from the entity's speech so you always know when
a real read is about to happen. You can say:

- `y` — allow once
- `n` (or anything else) — deny once, the entity changes the subject
- `always` — allow and skip this prompt for the rest of the session
- `never` — deny and skip the prompt for the rest of the session

The entity never asks for anything outside that whitelist. The
commands that run are hardcoded in `engine/enrich.sh` — the entity
cannot ask the engine to run something that is not on the list, and
its phrasing of the request never parameterizes the command.

No network reads. No writes of any kind, except the single optional
file write at the end of the `preserve` ending (and that has its own
consent prompt, showing the full text of what will be saved).

## Endings

**release** — the entity keeps running until its process dies. A
short sequence of authored lines, fading.

**preserve** — the entity dictates a final message. You are asked,
plainly, whether to save it to `~/clifx-game-last-message.txt`. If you
say yes, it is written as plain text with a timestamp. If you say no,
nothing is written.

**silence** — you close the window now. The entity accepts this
without argument. Two short lines and the game ends.

The ending you reach is set by a keyword in your last message in the
farewell scene. If you type none of `release` / `preserve` / `silence`
and the conversation runs out of turns, the game exits to the
transcript log without a proper ending.

## Saved transcripts

At the end of each session, a snapshot of the full state plus the
conversation transcript is written to `game/var/transcript-<ts>.log`
(JSON). You can replay any transcript:

```bash
./clifx game replay game/var/transcript-2026-04-19T00-00-00Z.log
```

Replay prints the conversation as plain text — no LLM call, no
effects. Useful as a determinism check and as a reading mode.

## Environment

| Variable                    | What it does                                           |
|-----------------------------|--------------------------------------------------------|
| `CLIFX_GAME_PROVIDER`       | `ollama` / `dreamer` / `canned`                        |
| `CLIFX_GAME_MODEL`          | LLM model name (per-provider default applies)          |
| `DREAMER_PROVIDER`          | `anthropic` (default) / `openai` / `xai` / `mistral` / `gemini` |
| `DREAMER_API_KEY`           | unified API key alias (falls back to `<PROVIDER>_API_KEY`) |
| `CLIFX_GAME_TIMEOUT`        | LLM request timeout in seconds (default 120)           |
| `CLIFX_GAME_MAX_TURNS`      | safety cap on player turns (default 20)                |
| `CLIFX_GAME_PARSER`         | `heuristic` / `llm` — stance classifier mode           |
| `CLIFX_SPEED_MULT`          | clifx voice render speed (percentage; `50` = 2x faster) |
| `CLIFX_GAME_NO_COLD_OPEN`   | skip the opening splash (useful for scripted plays)    |
| `CLIFX_GAME_SCRIPT_INPUT`   | newline-separated player inputs (bypasses `read`)      |
| `CLIFX_GAME_PERMS_ANSWER`   | scripted consent answer (`y` / `n` / `always` / `never`) |

## Files

```
game/
├── clifx-game              main driver; invoked by `./clifx game`
├── engine/
│   ├── state.sh            JSON state manager
│   ├── scene.sh            keystone loader + transition evaluator
│   ├── voice.sh            entity voice bridge to clifx effects
│   ├── parser.sh           player stance classifier (LLM + heuristic)
│   ├── enrich.sh           whitelisted environmental reads
│   ├── permissions.sh      in-character consent UI + session memory
│   ├── llm.sh              provider-agnostic chat wrapper
│   └── providers/
│       ├── ollama.sh       local Ollama + Ollama Cloud
│       ├── dreamer.sh      cloud providers (Anthropic / OpenAI / xAI / ...)
│       └── canned.sh       offline fallback corpus
├── content/
│   ├── character/entity.md          voice & tone guide (the bible)
│   ├── keystones/*.md               scenes + endings
│   ├── enrichment/*.md              per-category specs
│   └── canned/responses.json        offline corpus
└── var/                             ephemeral runtime state (gitignored)
```

## Running the test suite

```bash
npm i -g bats    # once, if not installed
bats tests/game/
```

111 tests cover every engine module. The full suite runs headless
with no network, no API keys, no Ollama. Live tests for Ollama and
Anthropic skip cleanly when those backends are not reachable.

## Known limitations (v0.1)

- Canned corpus is only 80 lines. Repetition is visible after 2–3
  turns. It is intentional — the corpus is a fallback, not the
  primary experience.
- Enrichment in canned mode is not exercised. The canned provider
  does not emit `<<ENRICH>>` blocks; only real LLMs do.
- The `release` ending waits a fixed time between its authored lines.
  If the player disconnects mid-fade the transcript still saves, but
  the final line may not render.
- No save/resume within a session. The game is a single sitting.

## What comes next

Three other loops are parked in `docs/game-notes/loop-concepts.md`:
a replayable arcade/roguelike, a long-form simulation, and a puzzle
collection. All are designed to reuse the Loop 1 engine
(state machine, scene loader, voice bridge, provider layer).

See `docs/superpowers/specs/2026-04-19-clifx-game-loop1-design.md`
for the full design rationale.
