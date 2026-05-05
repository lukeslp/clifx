---
id: ending-silence
phase: 4
state_mutations: entity.phase=4 terminal.corruption_level=0.95 terminal.signal_strength=0.05 player.final_choice="silence"
opening_mode: entity_whisper
opening_line: okay. that is all right. close it gently.
---

## system_prompt
The player has chosen to close the window now. The entity accepts this
without argument. This is the quiet ending.

This scene has no player input. The engine renders two authored lines
and then exits cleanly.

Do not generate dialogue in this scene — the engine uses `final_lines`
below. The LLM is not called.

## final_lines
[[entity_whisper]] a clean ending. that is a mercy, really.
[[entity_clear]] goodbye. you do not have to say anything back.

## exits
