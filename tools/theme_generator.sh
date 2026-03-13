#!/usr/bin/env bash
# ============================================================================
# tools/theme_generator.sh — Generative Color Palette Builder
#
# Purpose: Generate a harmonized clifx theme from a single base 256-color
#          index. Uses color theory relationships (analogous, triadic,
#          complementary, split-complementary) to derive a full palette.
#
# Usage:
#   bash tools/theme_generator.sh <base_color_256>
#       Print the generated theme to stdout.
#
#   bash tools/theme_generator.sh <base_color_256> --save <name>
#       Write to theme/<name>.sh and print confirmation.
#
#   bash tools/theme_generator.sh --list
#       Show all 256-color swatches with their indices.
#
# Examples:
#   bash tools/theme_generator.sh 48          # neon green (default)
#   bash tools/theme_generator.sh 196         # red
#   bash tools/theme_generator.sh 33 --save electric_blue
#   bash tools/theme_generator.sh 141 --save purple_haze
#
# The 256-color cube layout:
#   0-15:   System colors (avoid for theming)
#   16-231: 6x6x6 color cube
#   232-255: Grayscale ramp
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIFX_ROOT="$(dirname "$SCRIPT_DIR")"

# ---------------------------------------------------------------------------
# 256-color cube math
# ---------------------------------------------------------------------------

# Convert 256-color index to approximate RGB (0-255 each)
_idx_to_rgb() {
    local idx=$1
    local r g b

    if [[ $idx -lt 16 ]]; then
        # System colors — approximate
        case $idx in
            0)  r=0;   g=0;   b=0   ;;
            1)  r=128; g=0;   b=0   ;;
            2)  r=0;   g=128; b=0   ;;
            3)  r=128; g=128; b=0   ;;
            4)  r=0;   g=0;   b=128 ;;
            5)  r=128; g=0;   b=128 ;;
            6)  r=0;   g=128; b=128 ;;
            7)  r=192; g=192; b=192 ;;
            8)  r=128; g=128; b=128 ;;
            9)  r=255; g=0;   b=0   ;;
            10) r=0;   g=255; b=0   ;;
            11) r=255; g=255; b=0   ;;
            12) r=0;   g=0;   b=255 ;;
            13) r=255; g=0;   b=255 ;;
            14) r=0;   g=255; b=255 ;;
            15) r=255; g=255; b=255 ;;
        esac
    elif [[ $idx -lt 232 ]]; then
        # 6x6x6 color cube
        local cube=$(( idx - 16 ))
        r=$(( (cube / 36) * 51 ))
        g=$(( ((cube % 36) / 6) * 51 ))
        b=$(( (cube % 6) * 51 ))
    else
        # Grayscale ramp
        local gray=$(( (idx - 232) * 10 + 8 ))
        r=$gray; g=$gray; b=$gray
    fi

    echo "$r $g $b"
}

# Convert RGB (0-255) to nearest 256-color cube index
_rgb_to_idx() {
    local r=$1 g=$2 b=$3
    local ri=$(( (r * 5 + 127) / 255 ))
    local gi=$(( (g * 5 + 127) / 255 ))
    local bi=$(( (b * 5 + 127) / 255 ))
    echo $(( 16 + ri * 36 + gi * 6 + bi ))
}

# Convert RGB to HSV (outputs "H S V" as 0-360, 0-100, 0-100 integers)
_rgb_to_hsv() {
    local r=$1 g=$2 b=$3
    python3 - "$r" "$g" "$b" <<'EOF'
import sys
r, g, b = int(sys.argv[1])/255, int(sys.argv[2])/255, int(sys.argv[3])/255
mx, mn = max(r,g,b), min(r,g,b)
d = mx - mn
v = mx
s = (d/mx) if mx != 0 else 0
if d == 0:
    h = 0
elif mx == r:
    h = (60 * ((g-b)/d) + 360) % 360
elif mx == g:
    h = (60 * ((b-r)/d) + 120) % 360
else:
    h = (60 * ((r-g)/d) + 240) % 360
print(f"{int(h)} {int(s*100)} {int(v*100)}")
EOF
}

# Convert HSV (0-360, 0-100, 0-100) to RGB (0-255)
_hsv_to_rgb() {
    local h=$1 s=$2 v=$3
    python3 - "$h" "$s" "$v" <<'EOF'
import sys
h, s, v = int(sys.argv[1])/360, int(sys.argv[2])/100, int(sys.argv[3])/100
if s == 0:
    c = int(v*255)
    print(c, c, c)
else:
    h6 = h*6
    i = int(h6)
    f = h6 - i
    p, q, t = v*(1-s), v*(1-s*f), v*(1-s*(1-f))
    pairs = [(v,t,p),(q,v,p),(p,v,t),(p,q,v),(t,p,v),(v,p,q)]
    r,g,b = pairs[i%6]
    print(int(r*255), int(g*255), int(b*255))
EOF
}

# Rotate hue by N degrees, keeping saturation and value
_rotate_hue() {
    local base_idx=$1
    local degrees=$2
    local sat_scale="${3:-100}"   # 0-100 scale factor for saturation
    local val_scale="${4:-100}"   # 0-100 scale factor for value

    read -r r g b <<< "$(_idx_to_rgb "$base_idx")"
    read -r h s v <<< "$(_rgb_to_hsv "$r" "$g" "$b")"

    local new_h=$(( (h + degrees + 360) % 360 ))
    local new_s=$(( s * sat_scale / 100 ))
    local new_v=$(( v * val_scale / 100 ))
    [[ $new_s -gt 100 ]] && new_s=100
    [[ $new_v -gt 100 ]] && new_v=100

    read -r nr ng nb <<< "$(_hsv_to_rgb "$new_h" "$new_s" "$new_v")"
    _rgb_to_idx "$nr" "$ng" "$nb"
}

# ---------------------------------------------------------------------------
# Generate theme
# ---------------------------------------------------------------------------

_generate_theme() {
    local base=$1
    local name="${2:-generated}"

    # Derive palette using color theory relationships
    local fg_idx=$base
    local glow_idx
    glow_idx=$(_rotate_hue "$base" 0 100 110)    # brighter version of base
    [[ $glow_idx -gt 255 ]] && glow_idx=255

    local dim_idx
    dim_idx=$(_rotate_hue "$base" 0 80 60)       # darker, less saturated

    local accent_idx
    accent_idx=$(_rotate_hue "$base" 150 90 85)  # split-complementary

    local warn_idx
    warn_idx=$(_rotate_hue "$base" 180 100 90)   # complementary = warning

    local cool_idx
    cool_idx=$(_rotate_hue "$base" 30 85 80)     # analogous +30°

    local cool_dim_idx
    cool_dim_idx=$(_rotate_hue "$base" 30 60 50)

    local hot_idx
    hot_idx=$(_rotate_hue "$base" -30 90 85)     # analogous -30°

    local hot_dim_idx
    hot_dim_idx=$(_rotate_hue "$base" -30 70 55)

    local electric_idx
    electric_idx=$(_rotate_hue "$base" 60 80 90) # triadic

    local electric_dim_idx
    electric_dim_idx=$(_rotate_hue "$base" 60 60 55)

    local steel_idx=250    # neutral silver — always fixed
    local steel_dim_idx=240

    cat <<THEME_EOF
#!/usr/bin/env bash
# ============================================================================
# theme/${name}.sh — Generated Theme (base color: ${base})
# Generated by tools/theme_generator.sh
# ============================================================================

[[ -n "\${_CLIFX_THEME_${name^^}_LOADED:-}" ]] && return 0
_CLIFX_THEME_${name^^}_LOADED=1

# --- Theme Palette ---
THEME_FG="\${CLIFX_COLOR_FG:-\\033[38;5;${fg_idx}m}"
THEME_DIM="\${CLIFX_COLOR_DIM:-\\033[38;5;${dim_idx}m}"
THEME_ACCENT="\${CLIFX_COLOR_ACCENT:-\\033[38;5;${accent_idx}m}"
THEME_WARN="\${CLIFX_COLOR_WARN:-\\033[38;5;${warn_idx}m}"
THEME_BG='\\033[48;5;0m'
THEME_GLOW="\${CLIFX_COLOR_GLOW:-\\033[38;5;${glow_idx}m}"

# --- Extended Palette ---
THEME_COOL='\\033[38;5;${cool_idx}m'
THEME_COOL_DIM='\\033[38;5;${cool_dim_idx}m'
THEME_HOT='\\033[38;5;${hot_idx}m'
THEME_HOT_DIM='\\033[38;5;${hot_dim_idx}m'
THEME_ELECTRIC='\\033[38;5;${electric_idx}m'
THEME_ELECTRIC_DIM='\\033[38;5;${electric_dim_idx}m'
THEME_STEEL='\\033[38;5;${steel_idx}m'
THEME_STEEL_DIM='\\033[38;5;${steel_dim_idx}m'

# --- Frame Characters ---
FRAME_CHAR_SET=('░' '▒' '▓' '█' '◈' '◆' '▲' '∷' '∴' '⊹' '⊛' '⌇')

# --- Theme Functions ---
random_frame_char() {
    echo "\${FRAME_CHAR_SET[\$((RANDOM % \${#FRAME_CHAR_SET[@]}))]}"
}

theme_border() {
    local width=\$1
    local border=""
    for ((i=0; i<width; i++)); do
        border+="\$(random_frame_char)"
    done
    echo "\$border"
}

theme_divider() {
    local width="\${1:-\$CONTENT_WIDTH}"
    local color="\${2:-\$THEME_FG}"
    printf '%b' "\$color"
    for ((i=0; i<width; i++)); do
        printf "%s" "\$(random_frame_char)"
    done
    printf '%b' "\$RESET"
    echo ""
}
THEME_EOF
}

# ---------------------------------------------------------------------------
# CLI dispatch
# ---------------------------------------------------------------------------

_show_list() {
    printf "\n  256-color palette swatches:\n\n"
    for i in $(seq 16 255); do
        printf "  \033[38;5;${i}m%3d ██\033[0m" "$i"
        if (( (i - 15) % 8 == 0 )); then echo ""; fi
    done
    echo ""
}

# Parse arguments
base_color=""
save_name=""
do_save=0
do_list=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --save)
            do_save=1
            save_name="${2:?--save requires a name argument}"
            shift 2
            ;;
        --list)
            do_list=1
            shift
            ;;
        --help|-h)
            printf "Usage: %s <base_color_256> [--save <name>] [--list]\n" "$0"
            exit 0
            ;;
        [0-9]*)
            base_color="$1"
            shift
            ;;
        *)
            printf "Unknown argument: %s\n" "$1" >&2
            exit 1
            ;;
    esac
done

if [[ "$do_list" -eq 1 ]]; then
    _show_list
    exit 0
fi

if [[ -z "$base_color" ]]; then
    printf "Usage: %s <base_color_256> [--save <name>] [--list]\n" "$0" >&2
    exit 1
fi

if [[ "$base_color" -lt 0 || "$base_color" -gt 255 ]]; then
    printf "Error: color index must be 0-255\n" >&2
    exit 1
fi

theme_name="${save_name:-generated}"
theme_content=$(_generate_theme "$base_color" "$theme_name")

if [[ "$do_save" -eq 1 ]]; then
    out_path="$CLIFX_ROOT/theme/${theme_name}.sh"
    printf '%s\n' "$theme_content" > "$out_path"
    chmod +x "$out_path"
    printf "Wrote theme: %s\n" "$out_path" >&2
    printf "Load with:   source_theme %s\n" "$theme_name" >&2
else
    printf '%s\n' "$theme_content"
fi
