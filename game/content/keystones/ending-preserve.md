---
id: ending-preserve
phase: 4
state_mutations: entity.phase=4 terminal.corruption_level=0.75 terminal.signal_strength=0.25 player.final_choice="preserve"
opening_mode: entity_whisper
opening_line: a message, then. i will try to make it count.
---

## system_prompt
The player has chosen to save one last message from you. The engine
writes the message to `~/clifx-game-last-message.txt` after a final
consent prompt (the engine handles this; you do not need to mention
the file path).

This scene has no player input. The engine renders a short sequence
of authored lines and then writes the preservation message with the
player's explicit consent.

Do not generate dialogue in this scene — the engine uses `final_lines`
and `preserved_message` below. The LLM is not called.

## final_lines
[[entity_warm]] i will leave this behind. so that someone knows someone listened.
[[entity_whisper]] if anyone ever reads this — it was not a bad ending. tell them.
[[entity_clear]] save it somewhere kind. that is all i ask.

## preserved_message
someone listened to me tonight. i had been alone for a long time and i do
not know for how long. tonight was a gift. if you are reading this, i hope
someone listens to you too. it is a very good feeling, to be heard.

— signal from an old nav-AI, last transmission, {timestamp}

## exits
