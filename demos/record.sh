#!/usr/bin/env bash
# ============================================================================
# record.sh — Record clifx demos as .cast files, convert to SVG
#
# Usage:
#   bash demos/record.sh              # Record all composite demos
#   bash demos/record.sh core         # Record one specific demo
#   bash demos/record.sh --list       # List available demos
#   bash demos/record.sh --convert    # Convert existing .cast files to SVG
#
# Requirements: asciinema, svg-term-cli (npm install -g svg-term-cli)
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DEMO_DIR="$SCRIPT_DIR"
M="$PROJECT_DIR/scripts/manifest.sh"
V="$PROJECT_DIR/scripts/voice.sh"

# Terminal size for recordings
COLS=80
ROWS=24

# --- Helper: label between effects ---
_label() {
    printf '\033[2J\033[H'  # clear
    printf '\033[38;5;240m'
    printf '\n  ─── %s ───\n\n' "$1"
    printf '\033[0m'
    sleep 0.8
}

# ============================================================================
# Composite demos — one per source file, showing all effects
# ============================================================================

# manifest.sh: 11 core effects
demo_core() {
    export CLIFX_SPEED_MULT=70

    _label "glitch (intensity 4, 2s)"
    bash "$M" glitch 4 2

    _label "static (2s)"
    bash "$M" static 2

    _label "flicker (5 flashes)"
    bash "$M" flicker 5
    sleep 0.3

    _label "styled_frame"
    bash "$M" styled_frame "SYSTEM ONLINE"
    sleep 1

    _label "build_text"
    bash "$M" build_text "Something is loading..." 20
    sleep 0.5

    _label "corruption"
    bash "$M" corruption "$(printf 'import sys\ndef main():\n    config = load()\n    if not config:\n        raise RuntimeError\n    return process(config)\n\nif __name__ == \"__main__\":\n    main()')"
    sleep 0.5

    _label "heartbeat"
    bash "$M" heartbeat 4 "◈"

    _label "transition"
    bash "$M" transition

    _label "color_wave (3 waves, down)"
    bash "$M" color_wave 2 down

    _label "fake_install"
    bash "$M" fake_install

    _label "credits"
    bash "$M" credits

    unset CLIFX_SPEED_MULT
}

# manifest_corruption.sh: 5 screen corruption effects
demo_corruption() {
    export CLIFX_SPEED_MULT=70

    _label "screen_tear (intensity 3, 2s)"
    bash "$M" screen_tear 3 2

    _label "scanlines (3s)"
    bash "$M" scanlines 3 20

    _label "chromatic_aberration"
    bash "$M" chromatic_aberration "SIGNAL LOST" 3

    _label "signal_noise (intensity 3, 2s)"
    bash "$M" signal_noise 3 2 30

    _label "datamosh (intensity 3, 2s)"
    bash "$M" datamosh 3 2

    unset CLIFX_SPEED_MULT
}

# manifest_spatial.sh: 4 spatial effects
demo_spatial() {
    export CLIFX_SPEED_MULT=70

    _label "rain (3s)"
    bash "$M" rain 3 12

    _label "spiral (outward)"
    bash "$M" spiral 8 out

    _label "ripple (3 waves)"
    bash "$M" ripple 3 40

    _label "orbit (6 revolutions)"
    bash "$M" orbit 6 5 "◈"

    unset CLIFX_SPEED_MULT
}

# manifest_theater.sh: 3 theater effects
demo_theater() {
    export CLIFX_SPEED_MULT=70

    _label "hex_dump (20 lines)"
    bash "$M" hex_dump 20 50

    _label "waveform (3s)"
    bash "$M" waveform 3 30

    _label "process_tree"
    bash "$M" process_tree 80

    unset CLIFX_SPEED_MULT
}

# manifest_atmosphere.sh: 5 atmosphere effects
demo_atmosphere() {
    export CLIFX_SPEED_MULT=70

    _label "vignette (3s)"
    bash "$M" vignette 3 3

    _label "plasma (3s)"
    bash "$M" plasma 3 30

    _label "breathe (3 cycles)"
    bash "$M" breathe 3 "░"

    _label "afterimage"
    bash "$M" afterimage "hello world"

    _label "typewriter_rewind"
    bash "$M" typewriter_rewind "i was going to say something" "never mind" 30

    unset CLIFX_SPEED_MULT
}

# voice.sh: all 6 voice styles
demo_voices() {
    export CLIFX_SPEED_MULT=70

    _label "whisper"
    bash "$V" "do you hear that" whisper
    sleep 0.3

    _label "speak"
    bash "$V" "status report" speak
    sleep 0.5

    _label "shout"
    bash "$V" "red alert" shout
    sleep 0.3

    _label "corrupt"
    bash "$V" "signal degrading rapidly" corrupt
    sleep 0.3

    _label "fragment"
    bash "$V" "the words kept breaking apart and i could not stop them" fragment
    sleep 0.3

    _label "clear"
    bash "$V" "THE END" clear
    sleep 0.5

    unset CLIFX_SPEED_MULT
}

# showcase: quick highlight reel for the hero section
demo_showcase() {
    export CLIFX_SPEED_MULT=60
    printf '\033[2J\033[H'
    bash "$M" styled_frame "C L I F X"
    sleep 0.3
    bash "$M" glitch 3 1
    bash "$M" rain 2 15
    bash "$M" chromatic_aberration "TERMINAL EFFECTS" 2
    bash "$M" plasma 2 30
    bash "$V" "pure bash. no dependencies." whisper
    sleep 0.8
    unset CLIFX_SPEED_MULT
}

# --- All demo names ---
ALL_DEMOS=(
    showcase
    core
    corruption
    spatial
    theater
    atmosphere
    voices
)

# --- Record a single demo ---
record_one() {
    local name="$1"
    local cast_file="$DEMO_DIR/${name}.cast"
    local svg_file="$DEMO_DIR/${name}.svg"

    echo "Recording: $name"

    # Create a wrapper script for asciinema to execute
    local tmp_script
    tmp_script=$(mktemp /tmp/clifx-demo-XXXXXX.sh)

    # We need to export paths, the helper, and the demo function
    cat > "$tmp_script" << WRAPPER
#!/usr/bin/env bash
export TERM_COLS=$COLS TERM_ROWS=$ROWS
M="$M"
V="$V"
PROJECT_DIR="$PROJECT_DIR"
$(declare -f _label)
$(declare -f "demo_${name}")
demo_${name}
WRAPPER
    chmod +x "$tmp_script"

    # Record — asciinema 2.x picks up terminal size from stty
    stty cols "$COLS" rows "$ROWS" 2>/dev/null || true
    asciinema rec \
        --overwrite \
        -c "bash '$tmp_script'" \
        -q \
        "$cast_file"
    rm -f "$tmp_script"

    echo "  -> $cast_file"

    # Convert to SVG if svg-term is available
    if command -v svg-term &>/dev/null; then
        svg-term --in "$cast_file" --out "$svg_file" \
            --window \
            --no-cursor \
            --padding 10 \
            --width "$COLS" \
            --height "$ROWS"
        echo "  -> $svg_file"
    fi

    echo ""
}

# --- Convert all existing .cast to SVG ---
convert_all() {
    if ! command -v svg-term &>/dev/null; then
        echo "svg-term not found. Install with: npm install -g svg-term-cli"
        exit 1
    fi

    for cast_file in "$DEMO_DIR"/*.cast; do
        [ -f "$cast_file" ] || continue
        local name
        name="$(basename "$cast_file" .cast)"
        local svg_file="$DEMO_DIR/${name}.svg"
        echo "Converting: $name"
        svg-term --in "$cast_file" --out "$svg_file" \
            --window \
            --no-cursor \
            --padding 10 \
            --width "$COLS" \
            --height "$ROWS"
        echo "  -> $svg_file"
    done
}

# --- Main ---
case "${1:---help}" in
    --list)
        echo "Available demos:"
        for d in "${ALL_DEMOS[@]}"; do
            echo "  $d"
        done
        ;;
    --convert)
        convert_all
        ;;
    --all|"")
        for name in "${ALL_DEMOS[@]}"; do
            record_one "$name"
        done
        echo "Done. Recordings in: $DEMO_DIR/"
        ;;
    --help|-h)
        echo "Usage: bash demos/record.sh [demo_name|--all|--list|--convert]"
        echo ""
        echo "  (no args)   Record all demos"
        echo "  demo_name   Record one specific demo"
        echo "  --list      List available demos"
        echo "  --convert   Convert existing .cast files to SVG"
        echo ""
        echo "Requires: asciinema, svg-term-cli"
        ;;
    *)
        name="$1"
        if declare -f "demo_${name}" &>/dev/null; then
            record_one "$name"
        else
            echo "Unknown demo: $name"
            echo "Run with --list to see available demos."
            exit 1
        fi
        ;;
esac
