#!/usr/bin/env bash
set -euo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/nekoroshell"
WALLUST_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/wallust"
WAYBAR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/skins"
ROFI_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/skins"
SWAYNC_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/skins"
WLOGOUT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/wlogout/skins"
MODE="${1:-dark}"

case "${MODE,,}" in
    dark) ;;
    light) ;;
    *) echo "Error: mode must be dark or light." >&2; exit 1 ;;
esac

mkdir -p "$CACHE_DIR" "$WALLUST_DIR"

if [[ "${MODE,,}" == dark ]]; then
    BG="#0B090A"
    TEXT="#F4F6F5"  # exact inverse of #0B090A
    ACCENT="#D51F42"
    ACCENT_SOFT="#F0D8DC"
    INACTIVE="#5F5558"
    BG_ALPHA="0b090ae6"
else
    BG="#F4EEEE"
    TEXT="#0B1111"  # exact inverse of #F4EEEE
    ACCENT="#B91535"
    ACCENT_SOFT="#671224"
    INACTIVE="#A97B84"
    BG_ALPHA="f4eeeeeb"
fi

cat > "$WALLUST_DIR/colors-waybar.css" <<COLORS
@define-color background $BG;
@define-color foreground $TEXT;
@define-color cursor $TEXT;
@define-color color0 $BG;
@define-color color1 $ACCENT;
@define-color color2 $ACCENT;
@define-color color3 $ACCENT_SOFT;
@define-color color4 $TEXT;
@define-color color5 $ACCENT;
@define-color color6 $INACTIVE;
@define-color color7 $TEXT;
@define-color color8 $INACTIVE;
@define-color color9 $ACCENT;
@define-color color10 $TEXT;
@define-color color11 $TEXT;
@define-color color12 $ACCENT_SOFT;
@define-color color13 $TEXT;
@define-color color14 $INACTIVE;
@define-color color15 $TEXT;
@define-color text $TEXT;
@define-color text-invert $BG;
@define-color background-window #$BG_ALPHA;
@define-color background-input ${TEXT}20;
COLORS

cat > "$WALLUST_DIR/colors-rofi.rasi" <<COLORS
* {
    background: $BG;
    foreground: $TEXT;
    background-window: #$BG_ALPHA;
    background-input: ${TEXT}20;
    color0: $BG;
    color1: $ACCENT;
    color2: $ACCENT;
    color3: $ACCENT_SOFT;
    color4: $TEXT;
    color5: $ACCENT;
    color6: $INACTIVE;
    color7: $TEXT;
    color8: $INACTIVE;
    color9: $ACCENT;
    color10: $TEXT;
    color11: $TEXT;
    color12: $ACCENT_SOFT;
    color13: $TEXT;
    color14: $INACTIVE;
    color15: $TEXT;
    text: $TEXT;
    text-invert: $BG;
}
COLORS

cat > "$WALLUST_DIR/colors-hyprland.conf" <<COLORS
\$background = rgb(${BG#\#})
\$foreground = rgb(${TEXT#\#})
\$inactive = rgb(${INACTIVE#\#})
\$color0 = rgb(${BG#\#})
\$color1 = rgb(${ACCENT#\#})
\$color2 = rgb(${ACCENT#\#})
\$color3 = rgb(${ACCENT_SOFT#\#})
\$color4 = rgb(${TEXT#\#})
\$color5 = rgb(${ACCENT#\#})
\$color6 = rgb(${INACTIVE#\#})
\$color7 = rgb(${TEXT#\#})
\$color8 = rgb(${INACTIVE#\#})
\$color9 = rgb(${ACCENT#\#})
\$color10 = rgb(${TEXT#\#})
\$color11 = rgb(${TEXT#\#})
\$color12 = rgb(${ACCENT_SOFT#\#})
\$color13 = rgb(${TEXT#\#})
\$color14 = rgb(${INACTIVE#\#})
\$color15 = rgb(${TEXT#\#})
COLORS

cat > "$WALLUST_DIR/colors-kitty.conf" <<COLORS
foreground $TEXT
background $BG
background_opacity 1.0
cursor $TEXT

active_tab_foreground $BG
active_tab_background $TEXT
inactive_tab_foreground $TEXT
inactive_tab_background $BG

active_border_color $TEXT
inactive_border_color $BG
COLORS

printf '%s\n' "$HOME/.config/wallpapers/makima.mp4" > "$WALLUST_DIR/wal"
printf '%s\n' "${MODE,,}" > "$CACHE_DIR/theme_mode"
printf '%s\n' "makima-${MODE,,}" > "$CACHE_DIR/color_palette"

for d in "$WAYBAR_DIR"/*; do [[ -d "$d" ]] && cp -f "$WALLUST_DIR/colors-waybar.css" "$d/colors-wallust.css"; done
for d in "$ROFI_DIR"/*; do [[ -d "$d" ]] && cp -f "$WALLUST_DIR/colors-rofi.rasi" "$d/colors-wallust.rasi"; done
for d in "$SWAYNC_DIR"/*; do [[ -d "$d" ]] && cp -f "$WALLUST_DIR/colors-waybar.css" "$d/colors-wallust.css"; done
for d in "$WLOGOUT_DIR"/*; do [[ -d "$d" ]] && cp -f "$WALLUST_DIR/colors-waybar.css" "$d/colors-wallust.css"; done

killall -q navbar-hover navbar-watcher waybar 2>/dev/null || true
swaync-client -R >/dev/null 2>&1 || true
swaync-client -rs >/dev/null 2>&1 || true
case "$(cat "$CACHE_DIR/navbar_mode" 2>/dev/null || echo static)" in
    static) command -v waybar >/dev/null 2>&1 && waybar >/dev/null 2>&1 & ;;
    hover) command -v navbar-hover >/dev/null 2>&1 && navbar-hover >/dev/null 2>&1 & ;;
    *) command -v navbar-watcher >/dev/null 2>&1 && navbar-watcher >/dev/null 2>&1 & ;;
esac
