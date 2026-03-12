#!/usr/bin/env bash
# ============================================================================
# record.sh — Record clifx demos as .cast files, convert to SVG
#
# Usage:
#   bash demos/record.sh              # Record all demos
#   bash demos/record.sh rain         # Record one specific demo
#   bash demos/record.sh --list       # List available demos
#   bash demos/record.sh --convert    # Convert existing .cast files to SVG
#
# Requirements: asciinema, svg-term-cli (npm install -g svg-term-cli)
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DEMO_DIR="$SCRIPT_DIR"

# Terminal size for recordings (consistent across demos)
COLS=80
ROWS=24

# --- Demo definitions ---
# Each demo is a function that runs the effect with good args for recording.
# Keep them short (2-5 seconds) so the GIFs/SVGs aren't huge.

demo_rain() {
    bash "$PROJECT_DIR/scripts/manifest.sh" rain 2 12
}

demo_glitch() {
    bash "$PROJECT_DIR/scripts/manifest.sh" glitch 4 2
}

demo_static() {
    bash "$PROJECT_DIR/scripts/manifest.sh" static 2
}

demo_chromatic() {
    bash "$PROJECT_DIR/scripts/manifest.sh" chromatic_aberration "SIGNAL LOST" 3
}

demo_plasma() {
    bash "$PROJECT_DIR/scripts/manifest.sh" plasma 2 30
}

demo_spiral() {
    bash "$PROJECT_DIR/scripts/manifest.sh" spiral 8 out
}

demo_ripple() {
    bash "$PROJECT_DIR/scripts/manifest.sh" ripple 3 40
}

demo_orbit() {
    bash "$PROJECT_DIR/scripts/manifest.sh" orbit 6 5 "◈"
}

demo_hex_dump() {
    bash "$PROJECT_DIR/scripts/manifest.sh" hex_dump 20 60
}

demo_waveform() {
    bash "$PROJECT_DIR/scripts/manifest.sh" waveform 3 30
}

demo_screen_tear() {
    bash "$PROJECT_DIR/scripts/manifest.sh" screen_tear 3 2
}

demo_scanlines() {
    bash "$PROJECT_DIR/scripts/manifest.sh" scanlines 3 20
}

demo_datamosh() {
    bash "$PROJECT_DIR/scripts/manifest.sh" datamosh 3 2
}

demo_breathe() {
    bash "$PROJECT_DIR/scripts/manifest.sh" breathe 3 "░"
}

demo_vignette() {
    bash "$PROJECT_DIR/scripts/manifest.sh" vignette 3 3
}

demo_afterimage() {
    bash "$PROJECT_DIR/scripts/manifest.sh" afterimage "hello world"
}

demo_typewriter_rewind() {
    bash "$PROJECT_DIR/scripts/manifest.sh" typewriter_rewind "i was going to say something" "never mind" 35
}

demo_heartbeat() {
    bash "$PROJECT_DIR/scripts/manifest.sh" heartbeat 5 "◈"
}

demo_styled_frame() {
    bash "$PROJECT_DIR/scripts/manifest.sh" styled_frame "SYSTEM ONLINE"
}

demo_build_text() {
    bash "$PROJECT_DIR/scripts/manifest.sh" build_text "Something is loading..." 25
}

demo_fake_install() {
    bash "$PROJECT_DIR/scripts/manifest.sh" fake_install
}

demo_voice_whisper() {
    bash "$PROJECT_DIR/scripts/voice.sh" "do you hear that" whisper
}

demo_voice_shout() {
    bash "$PROJECT_DIR/scripts/voice.sh" "red alert" shout
}

demo_voice_corrupt() {
    bash "$PROJECT_DIR/scripts/voice.sh" "signal degrading rapidly" corrupt
}

demo_voice_fragment() {
    bash "$PROJECT_DIR/scripts/voice.sh" "the words kept breaking apart" fragment
}

# --- Showcase: quick montage of several effects ---
demo_showcase() {
    export CLIFX_SPEED_MULT=60
    clear
    bash "$PROJECT_DIR/scripts/manifest.sh" styled_frame "CLIFX"
    sleep 0.3
    bash "$PROJECT_DIR/scripts/manifest.sh" glitch 3 1
    bash "$PROJECT_DIR/scripts/manifest.sh" chromatic_aberration "TERMINAL EFFECTS" 2
    bash "$PROJECT_DIR/scripts/voice.sh" "pure bash. no dependencies." whisper
    sleep 0.5
    unset CLIFX_SPEED_MULT
}

# --- All demo names ---
ALL_DEMOS=(
    showcase
    rain glitch static chromatic plasma
    spiral ripple orbit
    hex_dump waveform
    screen_tear scanlines datamosh
    breathe vignette afterimage typewriter_rewind heartbeat
    styled_frame build_text fake_install
    voice_whisper voice_shout voice_corrupt voice_fragment
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
    cat > "$tmp_script" << WRAPPER
#!/usr/bin/env bash
source "$SCRIPT_DIR/../lib/core.sh" 2>/dev/null || true
export TERM_COLS=$COLS TERM_ROWS=$ROWS
$(declare -f "demo_${name}")
demo_${name}
WRAPPER
    chmod +x "$tmp_script"

    # Record with fixed terminal size via stty
    # asciinema 2.x picks up size from the terminal
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
        # Export demo functions so asciinema subshell can see them
        export PROJECT_DIR
        export -f demo_rain demo_glitch demo_static demo_chromatic demo_plasma
        export -f demo_spiral demo_ripple demo_orbit
        export -f demo_hex_dump demo_waveform
        export -f demo_screen_tear demo_scanlines demo_datamosh
        export -f demo_breathe demo_vignette demo_afterimage demo_typewriter_rewind demo_heartbeat
        export -f demo_styled_frame demo_build_text demo_fake_install
        export -f demo_voice_whisper demo_voice_shout demo_voice_corrupt demo_voice_fragment
        export -f demo_showcase

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
        # Record a single named demo
        name="$1"
        if declare -f "demo_${name}" &>/dev/null; then
            export PROJECT_DIR
            export -f "demo_${name}"
            record_one "$name"
        else
            echo "Unknown demo: $name"
            echo "Run with --list to see available demos."
            exit 1
        fi
        ;;
esac
