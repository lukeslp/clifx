#!/usr/bin/env bash
# ============================================================================
# tests/helpers/setup.bash — Shared test setup for clifx Bats test suites
# ============================================================================

# Resolve repo root relative to this file
CLIFX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Provide a minimal headless terminal environment so lib functions work
# without a real TTY.
export TERM="${TERM:-xterm-256color}"
export COLUMNS="${COLUMNS:-80}"
export LINES="${LINES:-24}"

# Prevent any effect from actually sleeping during tests
export CLIFX_SPEED_MULT=1

# Source core so helper functions are available in tests
source "$CLIFX_ROOT/lib/core.sh"

# Utility: strip all ANSI escape sequences from a string
strip_ansi() {
    printf '%s' "$1" | sed 's/\x1b\[[0-9;]*[mKHJABCDsuhl]//g'
}

# Utility: count lines in a string
line_count() {
    printf '%s' "$1" | wc -l
}
