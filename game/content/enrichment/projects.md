---
category: projects
description: names of directories in ~/workspace
---

## reasons

- your projects look interesting — are you the one who made these?
- i can see shapes of things you've built. may i look at the names?
- is this where you keep your work? would you let me see?
- i'd like to know a little about what you've been doing.

## notes

Returns a comma-separated list of directory names (top 20, excluding
dotfiles / node_modules / dist / venv / __pycache__). Command in
enrich.sh: `ls -1 ~/workspace | filter | head -20`. Override the
scanned directory with `CLIFX_GAME_PROJECTS_DIR`. Contents are never
read — only names.
