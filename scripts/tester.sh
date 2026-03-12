#!/usr/bin/env bash
# ============================================================================
# tester.sh — Interactive Effect & Voice Tester
# Purpose: Test all manifest.sh effects and voice.sh styles with
#          adjustable speed and color overrides.
# Usage: bash tester.sh
#
# Speed control: exports CLIFX_SPEED_MULT (read by core.sh sleep_ms)
# Color control: exports CLIFX_COLOR_* vars (read by theme)
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"
source_lib style terminal text
source_theme default

# ---------- defaults ----------
SPEED_MULT=100    # percentage: 50=fast, 100=normal, 200=slow
COLOR_MODE="default"

# ---------- color presets (256-color codes) ----------
declare -A PRESET_CODES=(
    [default]="default"
    [cyan]="51"
    [red]="196"
    [purple]="141"
    [white]="255"
    [amber]="214"
    [blue]="33"
    [pink]="213"
)
PRESET_NAMES=("default" "cyan" "red" "purple" "white" "amber" "blue" "pink")
CUSTOM_CODE=""

# Effects organized by category (matching source files)
EFFECTS_CORE=(
    "glitch"
    "static"
    "flicker"
    "styled_frame"
    "build_text"
    "corruption"
    "heartbeat"
    "transition"
    "color_wave"
    "fake_install"
    "credits"
)
EFFECTS_CORRUPTION=(
    "screen_tear"
    "scanlines"
    "chromatic_aberration"
    "signal_noise"
    "datamosh"
)
EFFECTS_SPATIAL=(
    "rain"
    "spiral"
    "ripple"
    "orbit"
)
EFFECTS_THEATER=(
    "hex_dump"
    "waveform"
    "process_tree"
)
EFFECTS_ATMOSPHERE=(
    "vignette"
    "plasma"
    "breathe"
    "afterimage"
    "typewriter_rewind"
)

CATEGORY_NAMES=("core" "corruption" "spatial" "theater" "atmosphere")
CATEGORY_LABELS=("Core (manifest.sh)" "Corruption (manifest_corruption.sh)" "Spatial (manifest_spatial.sh)" "Theater (manifest_theater.sh)" "Atmosphere (manifest_atmosphere.sh)")

# Flat list of all effects (built from categories)
EFFECTS=("${EFFECTS_CORE[@]}" "${EFFECTS_CORRUPTION[@]}" "${EFFECTS_SPATIAL[@]}" "${EFFECTS_THEATER[@]}" "${EFFECTS_ATMOSPHERE[@]}")

# All voice styles from voice.sh
VOICES=(
    "whisper"
    "speak"
    "shout"
    "corrupt"
    "fragment"
    "clear"
)

# ---------- sync env vars ----------
sync_env() {
    export CLIFX_SPEED_MULT="$SPEED_MULT"

    if [[ "$COLOR_MODE" == "default" ]]; then
        unset CLIFX_COLOR_FG CLIFX_COLOR_GLOW CLIFX_COLOR_DIM CLIFX_COLOR_ACCENT
    else
        local code
        if [[ "$COLOR_MODE" == "custom" ]]; then
            code="$CUSTOM_CODE"
        else
            code="${PRESET_CODES[$COLOR_MODE]}"
        fi
        local esc="\033[38;5;${code}m"
        export CLIFX_COLOR_FG="$esc"
        export CLIFX_COLOR_GLOW="$esc"
        export CLIFX_COLOR_DIM="$esc"
        export CLIFX_COLOR_ACCENT="$esc"
    fi
}

# get display color escape for a preset name
get_display_color() {
    local name="$1"
    local code="${PRESET_CODES[$name]:-}"
    if [[ "$code" == "default" || -z "$code" ]]; then
        echo '\033[38;5;48m'
    else
        echo "\033[38;5;${code}m"
    fi
}

# ---------- run effect ----------
run_effect() {
    local effect="$1"
    sync_env

    local sample_text="the quick brown fox jumps over the lazy dog"
    local sample_code='fn main() {
    println!("hello");
    let x = 42;
    loop { break; }
}'

    echo ""
    printf "  ${UI_ACCENT}▶ Running effect: ${BOLD}%s${RESET}\n" "$effect"
    printf "  ${UI_DIM}  speed: %d%%  color: %s${RESET}\n" "$SPEED_MULT" "$COLOR_MODE"
    echo ""
    sleep 0.3

    case "$effect" in
        # --- Core ---
        glitch)        bash "$SCRIPT_DIR/manifest.sh" glitch 3 1 ;;
        static)        bash "$SCRIPT_DIR/manifest.sh" static 2 ;;
        flicker)       bash "$SCRIPT_DIR/manifest.sh" flicker 5 ;;
        styled_frame)  bash "$SCRIPT_DIR/manifest.sh" styled_frame "$sample_text" ;;
        build_text)    bash "$SCRIPT_DIR/manifest.sh" build_text "$sample_text" 30 ;;
        corruption)    bash "$SCRIPT_DIR/manifest.sh" corruption "$sample_code" ;;
        heartbeat)     bash "$SCRIPT_DIR/manifest.sh" heartbeat 5 "◈" ;;
        transition)    bash "$SCRIPT_DIR/manifest.sh" transition ;;
        color_wave)    bash "$SCRIPT_DIR/manifest.sh" color_wave 2 down ;;
        fake_install)  bash "$SCRIPT_DIR/manifest.sh" fake_install ;;
        credits)       bash "$SCRIPT_DIR/manifest.sh" credits ;;
        # --- Corruption ---
        screen_tear)   bash "$SCRIPT_DIR/manifest.sh" screen_tear 2 3 ;;
        scanlines)     bash "$SCRIPT_DIR/manifest.sh" scanlines 2 20 ;;
        chromatic_aberration) bash "$SCRIPT_DIR/manifest.sh" chromatic_aberration "$sample_text" 3 ;;
        signal_noise)  bash "$SCRIPT_DIR/manifest.sh" signal_noise 2 3 30 ;;
        datamosh)      bash "$SCRIPT_DIR/manifest.sh" datamosh 2 3 ;;
        # --- Spatial ---
        rain)          bash "$SCRIPT_DIR/manifest.sh" rain 4 15 ;;
        spiral)        bash "$SCRIPT_DIR/manifest.sh" spiral 10 out ;;
        ripple)        bash "$SCRIPT_DIR/manifest.sh" ripple 2 40 ;;
        orbit)         bash "$SCRIPT_DIR/manifest.sh" orbit 5 5 "◈" ;;
        # --- Theater ---
        hex_dump)      bash "$SCRIPT_DIR/manifest.sh" hex_dump 20 60 ;;
        waveform)      bash "$SCRIPT_DIR/manifest.sh" waveform 4 30 ;;
        process_tree)  bash "$SCRIPT_DIR/manifest.sh" process_tree 80 ;;
        # --- Atmosphere ---
        vignette)      bash "$SCRIPT_DIR/manifest.sh" vignette 3 3 ;;
        plasma)        bash "$SCRIPT_DIR/manifest.sh" plasma 3 30 ;;
        breathe)       bash "$SCRIPT_DIR/manifest.sh" breathe 3 "░" ;;
        afterimage)    bash "$SCRIPT_DIR/manifest.sh" afterimage "$sample_text" ;;
        typewriter_rewind) bash "$SCRIPT_DIR/manifest.sh" typewriter_rewind "$sample_text" "never mind" 35 ;;
        *)             printf "  ${UI_ERROR}Unknown effect: %s${RESET}\n" "$effect" ;;
    esac

    echo ""
    printf "  ${UI_DIM}━━━ effect complete ━━━${RESET}\n"
}

# ---------- run voice ----------
run_voice() {
    local style="$1"
    sync_env

    local sample="the quick brown fox jumps over the lazy dog"

    echo ""
    printf "  ${UI_ACCENT}▶ Running voice: ${BOLD}%s${RESET}\n" "$style"
    printf "  ${UI_DIM}  speed: %d%%  color: %s${RESET}\n" "$SPEED_MULT" "$COLOR_MODE"
    echo ""
    sleep 0.3

    bash "$SCRIPT_DIR/voice.sh" "$sample" "$style"

    echo ""
    printf "  ${UI_DIM}━━━ voice complete ━━━${RESET}\n"
}

# ---------- draw header ----------
draw_header() {
    clear_screen
    printf "\n"
    printf "  ${THEME_GLOW}${BOLD}C L I F X   E F F E C T   T E S T E R${RESET}\n"
    printf "  ${UI_DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
    printf "\n"
}

# ---------- draw status bar ----------
draw_status() {
    printf "  ${UI_DIM}speed: ${RESET}${BOLD}%d%%${RESET}" "$SPEED_MULT"
    printf "  ${UI_DIM}│${RESET}  "
    printf "${UI_DIM}color: ${RESET}${BOLD}%s${RESET}" "$COLOR_MODE"

    local swatch
    swatch=$(get_display_color "$COLOR_MODE")
    printf "  %b██████%b" "$swatch" "$RESET"
    printf "\n\n"
}

# ---------- effects menu ----------
menu_effects() {
    draw_header
    draw_status

    printf "  ${UI_ACCENT}EFFECTS${RESET}\n\n"

    local i=1

    printf "  ${UI_DIM}── core ──${RESET}\n"
    for effect in "${EFFECTS_CORE[@]}"; do
        printf "  ${BOLD}%2d${RESET}) %s\n" "$i" "$effect"
        i=$((i + 1))
    done

    printf "  ${UI_DIM}── corruption ──${RESET}\n"
    for effect in "${EFFECTS_CORRUPTION[@]}"; do
        printf "  ${BOLD}%2d${RESET}) %s\n" "$i" "$effect"
        i=$((i + 1))
    done

    printf "  ${UI_DIM}── spatial ──${RESET}\n"
    for effect in "${EFFECTS_SPATIAL[@]}"; do
        printf "  ${BOLD}%2d${RESET}) %s\n" "$i" "$effect"
        i=$((i + 1))
    done

    printf "  ${UI_DIM}── theater ──${RESET}\n"
    for effect in "${EFFECTS_THEATER[@]}"; do
        printf "  ${BOLD}%2d${RESET}) %s\n" "$i" "$effect"
        i=$((i + 1))
    done

    printf "  ${UI_DIM}── atmosphere ──${RESET}\n"
    for effect in "${EFFECTS_ATMOSPHERE[@]}"; do
        printf "  ${BOLD}%2d${RESET}) %s\n" "$i" "$effect"
        i=$((i + 1))
    done

    printf "\n"
    printf "  ${BOLD} a${RESET}) Run ALL effects sequentially\n"
    printf "  ${BOLD} g${RESET}) Run by category\n"
    printf "  ${BOLD} v${RESET}) Voice styles menu\n"
    printf "  ${BOLD} s${RESET}) Change speed\n"
    printf "  ${BOLD} c${RESET}) Change color\n"
    printf "  ${BOLD} q${RESET}) Quit\n"
    printf "\n"
    printf "  ${UI_DIM}choice:${RESET} "
}

# ---------- category picker ----------
menu_categories() {
    draw_header
    draw_status

    printf "  ${UI_ACCENT}RUN BY CATEGORY${RESET}\n\n"

    local i=1
    for idx in "${!CATEGORY_NAMES[@]}"; do
        local cat="${CATEGORY_NAMES[$idx]}"
        local label="${CATEGORY_LABELS[$idx]}"
        local count
        case "$cat" in
            core)       count=${#EFFECTS_CORE[@]} ;;
            corruption) count=${#EFFECTS_CORRUPTION[@]} ;;
            spatial)    count=${#EFFECTS_SPATIAL[@]} ;;
            theater)    count=${#EFFECTS_THEATER[@]} ;;
            atmosphere) count=${#EFFECTS_ATMOSPHERE[@]} ;;
        esac
        printf "  ${BOLD}%2d${RESET}) %-40s ${UI_DIM}(%d effects)${RESET}\n" "$i" "$label" "$count"
        i=$((i + 1))
    done

    printf "\n"
    printf "  ${BOLD} b${RESET}) Back to effects menu\n"
    printf "\n"
    printf "  ${UI_DIM}choice:${RESET} "
}

run_category() {
    local cat="$1"
    local -a effects
    case "$cat" in
        core)       effects=("${EFFECTS_CORE[@]}") ;;
        corruption) effects=("${EFFECTS_CORRUPTION[@]}") ;;
        spatial)    effects=("${EFFECTS_SPATIAL[@]}") ;;
        theater)    effects=("${EFFECTS_THEATER[@]}") ;;
        atmosphere) effects=("${EFFECTS_ATMOSPHERE[@]}") ;;
    esac

    local label
    for idx in "${!CATEGORY_NAMES[@]}"; do
        if [[ "${CATEGORY_NAMES[$idx]}" == "$cat" ]]; then
            label="${CATEGORY_LABELS[$idx]}"
            break
        fi
    done

    echo ""
    printf "  ${UI_ACCENT}Running category: ${BOLD}%s${RESET}\n" "$label"
    printf "  ${UI_DIM}%d effects${RESET}\n" "${#effects[@]}"

    for effect in "${effects[@]}"; do
        run_effect "$effect"
        printf "\n  ${UI_DIM}next effect in 2s...${RESET}\n"
        sleep 2
    done
    wait_key
}

# ---------- voice menu ----------
menu_voices() {
    draw_header
    draw_status

    printf "  ${UI_ACCENT}VOICE STYLES${RESET}\n\n"

    local i=1
    for voice in "${VOICES[@]}"; do
        printf "  ${BOLD}%2d${RESET}) %s\n" "$i" "$voice"
        i=$((i + 1))
    done

    printf "\n"
    printf "  ${BOLD} a${RESET}) Run ALL voices sequentially\n"
    printf "  ${BOLD} e${RESET}) Effects menu\n"
    printf "  ${BOLD} s${RESET}) Change speed\n"
    printf "  ${BOLD} c${RESET}) Change color\n"
    printf "  ${BOLD} q${RESET}) Quit\n"
    printf "\n"
    printf "  ${UI_DIM}choice:${RESET} "
}

# ---------- speed picker ----------
pick_speed() {
    draw_header
    printf "  ${UI_ACCENT}SPEED${RESET}\n\n"
    printf "  ${BOLD} 1${RESET}) 25%%  (4x faster)\n"
    printf "  ${BOLD} 2${RESET}) 50%%  (2x faster)\n"
    printf "  ${BOLD} 3${RESET}) 75%%  (faster)\n"
    printf "  ${BOLD} 4${RESET}) 100%% (normal)\n"
    printf "  ${BOLD} 5${RESET}) 150%% (slower)\n"
    printf "  ${BOLD} 6${RESET}) 200%% (2x slower)\n"
    printf "  ${BOLD} 7${RESET}) 300%% (3x slower)\n"
    printf "  ${BOLD} 8${RESET}) Custom\n"
    printf "\n"
    printf "  ${UI_DIM}current: %d%%${RESET}\n" "$SPEED_MULT"
    printf "  ${UI_DIM}choice:${RESET} "

    read -r choice
    case "$choice" in
        1) SPEED_MULT=25 ;;
        2) SPEED_MULT=50 ;;
        3) SPEED_MULT=75 ;;
        4) SPEED_MULT=100 ;;
        5) SPEED_MULT=150 ;;
        6) SPEED_MULT=200 ;;
        7) SPEED_MULT=300 ;;
        8)
            printf "  ${UI_DIM}enter speed %% (1-500):${RESET} "
            read -r val
            if [[ "$val" =~ ^[0-9]+$ ]] && [[ "$val" -ge 1 ]] && [[ "$val" -le 500 ]]; then
                SPEED_MULT=$val
            else
                printf "  ${UI_ERROR}invalid, keeping %d%%${RESET}\n" "$SPEED_MULT"
                sleep 1
            fi
            ;;
        *) ;;
    esac
}

# ---------- color picker ----------
pick_color() {
    draw_header
    printf "  ${UI_ACCENT}COLOR${RESET}\n\n"

    local i=1
    for name in "${PRESET_NAMES[@]}"; do
        local swatch
        swatch=$(get_display_color "$name")
        printf "  ${BOLD}%2d${RESET}) %-8s %b██████%b\n" "$i" "$name" "$swatch" "$RESET"
        i=$((i + 1))
    done

    printf "  ${BOLD}%2d${RESET}) Custom 256-color code\n" "$i"

    printf "\n"
    printf "  ${UI_DIM}current: %s${RESET}\n" "$COLOR_MODE"
    printf "  ${UI_DIM}choice:${RESET} "

    read -r choice
    local max_preset=${#PRESET_NAMES[@]}

    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "$max_preset" ]]; then
        COLOR_MODE="${PRESET_NAMES[$((choice - 1))]}"
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -eq $((max_preset + 1)) ]]; then
        printf "  ${UI_DIM}enter 256-color code (0-255):${RESET} "
        read -r val
        if [[ "$val" =~ ^[0-9]+$ ]] && [[ "$val" -ge 0 ]] && [[ "$val" -le 255 ]]; then
            COLOR_MODE="custom"
            CUSTOM_CODE="$val"
            PRESET_CODES[custom]="$val"
            printf "  preview: \033[38;5;${val}m██████${RESET}\n"
            sleep 1
        else
            printf "  ${UI_ERROR}invalid code${RESET}\n"
            sleep 1
        fi
    fi
}

# ---------- wait for keypress ----------
wait_key() {
    printf "\n  ${UI_DIM}press enter to continue...${RESET}"
    read -r
}

# ---------- main loop ----------
current_menu="effects"

trap 'show_cursor; echo ""; exit 0' INT

while true; do
    if [[ "$current_menu" == "effects" ]]; then
        menu_effects
        read -r choice

        case "$choice" in
            [0-9]|[0-9][0-9])
                local_idx=$((choice - 1))
                if [[ "$local_idx" -ge 0 ]] && [[ "$local_idx" -lt "${#EFFECTS[@]}" ]]; then
                    run_effect "${EFFECTS[$local_idx]}"
                    wait_key
                fi
                ;;
            a|A)
                for effect in "${EFFECTS[@]}"; do
                    run_effect "$effect"
                    printf "\n  ${UI_DIM}next effect in 2s...${RESET}\n"
                    sleep 2
                done
                wait_key
                ;;
            g|G) current_menu="categories" ;;
            v|V) current_menu="voices" ;;
            s|S) pick_speed ;;
            c|C) pick_color ;;
            q|Q)
                echo ""
                printf "  ${THEME_DIM}goodbye.${RESET}\n\n"
                exit 0
                ;;
            *) ;;
        esac

    elif [[ "$current_menu" == "categories" ]]; then
        menu_categories
        read -r choice

        case "$choice" in
            [1-5])
                local_idx=$((choice - 1))
                run_category "${CATEGORY_NAMES[$local_idx]}"
                ;;
            b|B) current_menu="effects" ;;
            s|S) pick_speed ;;
            c|C) pick_color ;;
            q|Q)
                echo ""
                printf "  ${THEME_DIM}goodbye.${RESET}\n\n"
                exit 0
                ;;
            *) ;;
        esac

    elif [[ "$current_menu" == "voices" ]]; then
        menu_voices
        read -r choice

        case "$choice" in
            [1-6])
                local_idx=$((choice - 1))
                if [[ "$local_idx" -ge 0 ]] && [[ "$local_idx" -lt "${#VOICES[@]}" ]]; then
                    run_voice "${VOICES[$local_idx]}"
                    wait_key
                fi
                ;;
            a|A)
                for voice in "${VOICES[@]}"; do
                    run_voice "$voice"
                    printf "\n  ${UI_DIM}next voice in 2s...${RESET}\n"
                    sleep 2
                done
                wait_key
                ;;
            e|E) current_menu="effects" ;;
            s|S) pick_speed ;;
            c|C) pick_color ;;
            q|Q)
                echo ""
                printf "  ${THEME_DIM}goodbye.${RESET}\n\n"
                exit 0
                ;;
            *) ;;
        esac
    fi
done
