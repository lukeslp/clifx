# clifx Game — Loop Concepts Backlog

Parked here during brainstorming on 2026-04-19. The active design target is **Loop 1 (Short experience)**; the other three are future experiments using the same engine, once Loop 1 is shipped and the clifx engine has been stressed.

## Loop 1 — Short narrative experience (ACTIVE)

One story, one (or a few branching) endings. 20–60 minute playtime. Heavy on clifx voices, corruption effects, and typewriter_rewind. Story-first, minimal mechanics. Shippable as a single `.sh` you pipe to bash.

## Loop 2 — Replayable arcade / roguelike

10-minute sessions. Random runs, permadeath or high-score loop. clifx physics + spatial effects (particles, rain, explosion, process_tree as encounters). Needs real-time input loop or turn grid. Parks until Loop 1 proves the engine.

## Loop 3 — Long-form simulation / incremental

Surveillance network, failing server, or distress-call relay that evolves over sessions. Save state. clifx effects are diegetic (the glitches ARE the gameplay). Idle-friendly.

## Loop 4 — Puzzle collection

Discrete levels — corrupted signals to decrypt, logic puzzles rendered through clifx effects. Escalating difficulty. Grows by adding level files, not changing the engine.

## Cross-cutting observations

- All four benefit from the same engine work: a scene/beat format, a voice-routing layer, a capability/fallback engine, a save/state primitive (for 2/3/4 only).
- Concept #1 deliberately avoids real-time input so the engine doesn't need non-blocking stdin yet. That work lands with Loop 2.
- Concept #3's save format will likely generalize to Loop 4's level-progress store.
