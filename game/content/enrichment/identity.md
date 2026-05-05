---
category: identity
description: your git identity (name and email from ~/.gitconfig)
---

## reasons

Phrasings the entity can use when asking to know the player's name. The
engine picks one (or the LLM composes a new one with the same warmth).

- may i know what to call you?
- what is your name, if you'd like to tell me?
- i'd like to know who i'm talking to, if that's okay.
- i don't know your name yet. would you share it?
- the shape of you has a name, doesn't it? would you say it to me?

## notes

Stored as a single string: `"Name (email)"` if both git fields are set,
`"Name"` if only name, `"unknown"` otherwise. Command in enrich.sh:
`git config user.name` + `git config user.email`. Never parameterized.
