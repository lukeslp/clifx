#!/usr/bin/env bash
# ============================================================================
# lib/layout.sh — Advanced Layout Primitives
#
# Purpose: Provides a grid and panel layout engine for building multi-region
#          terminal dashboards. Panels are independently addressable regions
#          with their own coordinate systems, enabling complex UIs without
#          manual cursor math.
#
# Depends: core.sh, style.sh, terminal.sh, box.sh
#
# Key concepts:
#   Panel:   A named rectangular region (x, y, w, h) in terminal coordinates.
#   Grid:    A regular subdivision of the terminal into equal-sized cells.
#   Widget:  A function that renders into a panel's coordinate space.
#
# Usage:
#   source_lib layout
#
#   # Create panels
#   layout_panel_create "header"  1  1  $TERM_COLS 3
#   layout_panel_create "sidebar" 1  4  20         $((TERM_ROWS - 4))
#   layout_panel_create "main"    22 4  $((TERM_COLS - 22)) $((TERM_ROWS - 4))
#
#   # Draw into a panel
#   layout_panel_clear "header"
#   layout_panel_print "header" 1 1 "Dashboard v1.0"
#
#   # Draw a border around a panel
#   layout_panel_border "sidebar" single
# ============================================================================

[[ -n "${_CLIFX_LAYOUT_LOADED:-}" ]] && return 0
_CLIFX_LAYOUT_LOADED=1

# ---------------------------------------------------------------------------
# Internal panel registry
# Panels are stored as: _LAYOUT_PANEL_<NAME>="x y w h"
# ---------------------------------------------------------------------------
declare -A _LAYOUT_PANELS=()

# ---------------------------------------------------------------------------
# layout_panel_create — Register a named panel
#
# Usage: layout_panel_create <name> <x> <y> <w> <h>
#   name: unique panel identifier
#   x, y: top-left corner (1-indexed terminal coordinates)
#   w, h: width and height in characters/rows
# ---------------------------------------------------------------------------
layout_panel_create() {
    local name="$1" x="$2" y="$3" w="$4" h="$5"
    _LAYOUT_PANELS["$name"]="$x $y $w $h"
}

# ---------------------------------------------------------------------------
# layout_panel_get — Read panel geometry into local variables
#
# Usage: layout_panel_get <name>
# Sets: _LP_X, _LP_Y, _LP_W, _LP_H
# Returns 1 if panel not found.
# ---------------------------------------------------------------------------
layout_panel_get() {
    local name="$1"
    if [[ -z "${_LAYOUT_PANELS[$name]:-}" ]]; then
        printf "layout: panel '%s' not found\n" "$name" >&2
        return 1
    fi
    read -r _LP_X _LP_Y _LP_W _LP_H <<< "${_LAYOUT_PANELS[$name]}"
}

# ---------------------------------------------------------------------------
# layout_panel_clear — Erase all content within a panel
# ---------------------------------------------------------------------------
layout_panel_clear() {
    local name="$1"
    layout_panel_get "$name" || return 1
    local blank
    blank=$(printf '%*s' "$_LP_W" "")
    for (( row = 0; row < _LP_H; row++ )); do
        move_cursor $(( _LP_Y + row )) "$_LP_X"
        printf '%s' "$blank"
    done
}

# ---------------------------------------------------------------------------
# layout_panel_print — Print text at a position relative to a panel
#
# Usage: layout_panel_print <name> <rel_col> <rel_row> <text>
#   rel_col, rel_row: 1-indexed position within the panel
#   text: will be truncated to fit within panel width
# ---------------------------------------------------------------------------
layout_panel_print() {
    local name="$1" rel_col="$2" rel_row="$3"
    shift 3
    local text="$*"

    layout_panel_get "$name" || return 1

    local abs_col=$(( _LP_X + rel_col - 1 ))
    local abs_row=$(( _LP_Y + rel_row - 1 ))

    # Truncate text to available width
    local max_w=$(( _LP_W - rel_col + 1 ))
    if [[ "${#text}" -gt "$max_w" ]]; then
        text="${text:0:$max_w}"
    fi

    move_cursor "$abs_row" "$abs_col"
    printf '%s' "$text"
}

# ---------------------------------------------------------------------------
# layout_panel_border — Draw a box border around a panel
#
# Usage: layout_panel_border <name> [style]
#   style: single (default), double, rounded, heavy
# ---------------------------------------------------------------------------
layout_panel_border() {
    local name="$1"
    local style="${2:-single}"

    layout_panel_get "$name" || return 1

    # Border character sets
    local tl tr bl br h v
    case "$style" in
        double)  tl='╔'; tr='╗'; bl='╚'; br='╝'; h='═'; v='║' ;;
        rounded) tl='╭'; tr='╮'; bl='╰'; br='╯'; h='─'; v='│' ;;
        heavy)   tl='┏'; tr='┓'; bl='┗'; br='┛'; h='━'; v='┃' ;;
        *)       tl='┌'; tr='┐'; bl='└'; br='┘'; h='─'; v='│' ;;
    esac

    local inner_w=$(( _LP_W - 2 ))
    local h_line
    h_line=$(printf '%*s' "$inner_w" "" | tr ' ' "$h")

    # Top border
    move_cursor "$_LP_Y" "$_LP_X"
    printf '%s%s%s' "$tl" "$h_line" "$tr"

    # Side borders
    for (( row = 1; row < _LP_H - 1; row++ )); do
        move_cursor $(( _LP_Y + row )) "$_LP_X"
        printf '%s' "$v"
        move_cursor $(( _LP_Y + row )) $(( _LP_X + _LP_W - 1 ))
        printf '%s' "$v"
    done

    # Bottom border
    move_cursor $(( _LP_Y + _LP_H - 1 )) "$_LP_X"
    printf '%s%s%s' "$bl" "$h_line" "$br"
}

# ---------------------------------------------------------------------------
# layout_panel_title — Print a title in the top border of a panel
#
# Usage: layout_panel_title <name> <title> [color]
# Requires the panel to have been bordered first.
# ---------------------------------------------------------------------------
layout_panel_title() {
    local name="$1" title="$2" color="${3:-}"
    layout_panel_get "$name" || return 1

    # Truncate title to fit within border
    local max_title=$(( _LP_W - 4 ))
    [[ "${#title}" -gt "$max_title" ]] && title="${title:0:$max_title}"

    move_cursor "$_LP_Y" $(( _LP_X + 2 ))
    printf '%b%s%b' "$color" " $title " "$RESET"
}

# ---------------------------------------------------------------------------
# layout_grid_create — Subdivide the terminal into a regular grid of panels
#
# Usage: layout_grid_create <prefix> <cols> <rows> [margin]
#   prefix: name prefix for generated panels (e.g., "cell" → cell_0_0, cell_0_1)
#   cols:   number of columns
#   rows:   number of rows
#   margin: gap between cells in characters (default: 0)
#
# Panels are named: <prefix>_<col>_<row>
# ---------------------------------------------------------------------------
layout_grid_create() {
    local prefix="$1" gcols="$2" grows="$3" margin="${4:-0}"

    local cell_w=$(( (TERM_COLS - margin * (gcols + 1)) / gcols ))
    local cell_h=$(( (TERM_ROWS - margin * (grows + 1)) / grows ))

    for (( gc = 0; gc < gcols; gc++ )); do
        for (( gr = 0; gr < grows; gr++ )); do
            local px=$(( margin + gc * (cell_w + margin) + 1 ))
            local py=$(( margin + gr * (cell_h + margin) + 1 ))
            layout_panel_create "${prefix}_${gc}_${gr}" "$px" "$py" "$cell_w" "$cell_h"
        done
    done
}

# ---------------------------------------------------------------------------
# layout_grid_border_all — Draw borders on all cells of a grid
#
# Usage: layout_grid_border_all <prefix> <cols> <rows> [style]
# ---------------------------------------------------------------------------
layout_grid_border_all() {
    local prefix="$1" gcols="$2" grows="$3" style="${4:-single}"
    for (( gc = 0; gc < gcols; gc++ )); do
        for (( gr = 0; gr < grows; gr++ )); do
            layout_panel_border "${prefix}_${gc}_${gr}" "$style"
        done
    done
}

# ---------------------------------------------------------------------------
# layout_panel_hfill — Fill a panel row with a repeated character
#
# Usage: layout_panel_hfill <name> <rel_row> <char> [color]
# ---------------------------------------------------------------------------
layout_panel_hfill() {
    local name="$1" rel_row="$2" char="$3" color="${4:-}"
    layout_panel_get "$name" || return 1

    local abs_row=$(( _LP_Y + rel_row - 1 ))
    local fill
    fill=$(printf '%*s' "$_LP_W" "" | tr ' ' "$char")

    move_cursor "$abs_row" "$_LP_X"
    printf '%b%s%b' "$color" "$fill" "$RESET"
}

# ---------------------------------------------------------------------------
# layout_panel_vfill — Fill a panel column with a repeated character
#
# Usage: layout_panel_vfill <name> <rel_col> <char> [color]
# ---------------------------------------------------------------------------
layout_panel_vfill() {
    local name="$1" rel_col="$2" char="$3" color="${4:-}"
    layout_panel_get "$name" || return 1

    local abs_col=$(( _LP_X + rel_col - 1 ))
    for (( row = 0; row < _LP_H; row++ )); do
        move_cursor $(( _LP_Y + row )) "$abs_col"
        printf '%b%s%b' "$color" "$char" "$RESET"
    done
}

# ---------------------------------------------------------------------------
# layout_panel_progress — Draw a progress bar inside a panel
#
# Usage: layout_panel_progress <name> <rel_col> <rel_row> <width> <pct> [color]
#   pct: 0-100
# ---------------------------------------------------------------------------
layout_panel_progress() {
    local name="$1" rel_col="$2" rel_row="$3" bar_w="$4" pct="$5"
    local color="${6:-}"

    layout_panel_get "$name" || return 1

    local filled=$(( bar_w * pct / 100 ))
    local empty=$(( bar_w - filled ))

    local bar_fill bar_empty
    bar_fill=$(printf '%*s' "$filled" "" | tr ' ' '█')
    bar_empty=$(printf '%*s' "$empty" "" | tr ' ' '░')

    layout_panel_print "$name" "$rel_col" "$rel_row" \
        "$(printf '%b%s%b%s' "$color" "$bar_fill" "$RESET" "$bar_empty")"
}

# ---------------------------------------------------------------------------
# layout_demo — Draw a sample 3-panel dashboard layout
# ---------------------------------------------------------------------------
layout_demo() {
    clear_screen
    hide_cursor

    local header_h=3
    local footer_h=2
    local sidebar_w=22
    local main_x=$(( sidebar_w + 1 ))
    local main_w=$(( TERM_COLS - sidebar_w ))
    local body_h=$(( TERM_ROWS - header_h - footer_h ))

    layout_panel_create "header"  1          1                "$TERM_COLS"  "$header_h"
    layout_panel_create "sidebar" 1          $(( header_h+1 )) "$sidebar_w" "$body_h"
    layout_panel_create "main"    "$main_x"  $(( header_h+1 )) "$main_w"    "$body_h"
    layout_panel_create "footer"  1          $(( TERM_ROWS - footer_h + 1 )) "$TERM_COLS" "$footer_h"

    layout_panel_border "header"  "rounded"
    layout_panel_border "sidebar" "single"
    layout_panel_border "main"    "double"
    layout_panel_border "footer"  "rounded"

    layout_panel_title "header"  "clifx layout demo"  "$THEME_GLOW"
    layout_panel_title "sidebar" "Navigation"         "$THEME_ACCENT"
    layout_panel_title "main"    "Content"            "$THEME_FG"

    layout_panel_print "sidebar" 2 2 "${THEME_FG}> Effects${RESET}"
    layout_panel_print "sidebar" 2 3 "${UI_DIM}  Animations${RESET}"
    layout_panel_print "sidebar" 2 4 "${UI_DIM}  Themes${RESET}"
    layout_panel_print "sidebar" 2 5 "${UI_DIM}  Interactive${RESET}"

    layout_panel_print "main" 2 2 "${THEME_FG}Welcome to the layout engine.${RESET}"
    layout_panel_print "main" 2 3 "${UI_DIM}Panels are independently addressable regions.${RESET}"
    layout_panel_print "main" 2 5 "${THEME_ACCENT}Progress:${RESET}"
    layout_panel_progress "main" 2 6 $(( main_w - 4 )) 72 "$THEME_GLOW"
    layout_panel_print "main" 2 7 "${UI_DIM}72% complete${RESET}"

    layout_panel_print "footer" 2 1 "${UI_DIM}q: quit  arrows: navigate  ?: help${RESET}"

    show_cursor
}
