#!/usr/bin/env bash
set -euo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/nekoroshell"
THUMB_CACHE="$CACHE_DIR/wallpaper-thumbs"
STATE_FILE="$CACHE_DIR/theme_mode"
WAYBAR_MODE_FILE="$CACHE_DIR/navbar_mode"
WALLUST_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/wallust"
waybar_colors="$WALLUST_DIR/colors-waybar.css"
rofi_colors="$WALLUST_DIR/colors-rofi.rasi"
hypr_colors="$WALLUST_DIR/colors-hyprland.conf"

MANAGEMENT_MODE=$(cat "$WAYBAR_MODE_FILE" 2>/dev/null || echo "static")

STATIC_PALETTE="$(cat "$CACHE_DIR/color_palette" 2>/dev/null || true)"
if [[ "$STATIC_PALETTE" == makima-* || "$STATIC_PALETTE" == makima ]]; then
    bash "$(dirname "$(readlink -f "$0")")/apply-makima-palette.sh" "${STATIC_PALETTE#makima-}"
    exit 0
fi

img_path="${1:-$(cat "$WALLUST_DIR/wal" 2>/dev/null || echo "")}" 
current_theme="${2:-$(cat "$STATE_FILE" 2>/dev/null || echo "Dark")}" 

[[ -z "$img_path" ]] && exit 0

mkdir -p "$THUMB_CACHE" "$WALLUST_DIR"
FILENAME=$(basename "$img_path")
THUMB_PATH="$THUMB_CACHE/${FILENAME}.jpg"
TARGET_IMG="$img_path"
[[ -f "$THUMB_PATH" ]] && TARGET_IMG="$THUMB_PATH"

case "${img_path##*.}" in
    mp4|mkv|webm|MP4|MKV|WEBM)
        VIDEO_FRAME="$THUMB_CACHE/${FILENAME}.jpg"
        if [[ ! -f "$VIDEO_FRAME" ]]; then
            ffmpeg -y -ss 00:00:03 -i "$img_path" -frames:v 1 -vf "scale=400:-1" "$VIDEO_FRAME" >/dev/null 2>&1 || true
        fi
        [[ -f "$VIDEO_FRAME" ]] && TARGET_IMG="$VIDEO_FRAME"
        ;;
esac

command -v wallust >/dev/null 2>&1 || exit 0
[[ -f "$TARGET_IMG" ]] || exit 0

if [[ "$current_theme" == "Dark" ]]; then
    wallust run "$TARGET_IMG" -q -C ~/.config/wallust/wallust-dark.toml || \
        wallust run "$TARGET_IMG" -q -C ~/.config/wallust/wallust-dark.toml -b full -t 5
else
    wallust run "$TARGET_IMG" -q -C ~/.config/wallust/wallust-light.toml || \
        wallust run "$TARGET_IMG" -q -C ~/.config/wallust/wallust-light.toml -b full -t 5
fi

[[ -f "$WALLUST_DIR/colors-hyprland-raw.conf" ]] && mv -f "$WALLUST_DIR/colors-hyprland-raw.conf" "$hypr_colors"

# Publish generated UI palettes atomically. Rofi/GTK readers can otherwise observe
# a half-written file while Wallust or cp is updating it, which manifests as a
# transient "Parsing error" after switching themes.
hex_inverse() {
    local h="${1#\#}"
    [[ "$h" =~ ^[0-9A-Fa-f]{6}$ ]] || return 1
    local r=$((16#${h:0:2})) g=$((16#${h:2:2})) b=$((16#${h:4:2}))
    printf '#%02X%02X%02X' $((255-r)) $((255-g)) $((255-b))
}

BG_HEX=""
if [[ -f "$waybar_colors" ]]; then
    BG_HEX="$(sed -n 's/^@define-color background \(#\?[0-9A-Fa-f]\{6\}\).*/\1/p' "$waybar_colors" | head -n1)"
fi
[[ -n "$BG_HEX" ]] || BG_HEX="#161616"
[[ "$BG_HEX" == \#* ]] || BG_HEX="#$BG_HEX"
TEXT_HEX="$(hex_inverse "$BG_HEX")" || TEXT_HEX="#E9E9E9"
BG_PLAIN="${BG_HEX#\#}"
TEXT_PLAIN="${TEXT_HEX#\#}"

publish_atomic() {
    local source="$1" target="$2"
    local dir base tmp
    [[ -f "$source" ]] || return 0
    dir="$(dirname "$target")"
    base="$(basename "$target")"
    mkdir -p "$dir"
    tmp="$(mktemp "$dir/.${base}.nks.XXXXXX")"
    cp -f -- "$source" "$tmp"
    chmod --reference="$source" "$tmp" 2>/dev/null || true
    mv -f -- "$tmp" "$target"
}

# Never edit an actively consumed generated file in place. Build a temporary
# transformed copy and replace it in one rename operation.
if [[ -f "$waybar_colors" ]]; then
    tmp="$(mktemp "$WALLUST_DIR/.colors-waybar.css.nks.XXXXXX")"
    cp -f -- "$waybar_colors" "$tmp"
    sed -i \
        -e "s|^@define-color foreground .*|@define-color foreground $TEXT_HEX;|" \
        -e "s|^@define-color text .*|@define-color text $TEXT_HEX;|" \
        -e "s|^@define-color text-invert .*|@define-color text-invert $BG_HEX;|" \
        "$tmp"
    grep -q '^@define-color text ' "$tmp" || printf '@define-color text %s;\n' "$TEXT_HEX" >> "$tmp"
    grep -q '^@define-color text-invert ' "$tmp" || printf '@define-color text-invert %s;\n' "$BG_HEX" >> "$tmp"
    mv -f -- "$tmp" "$waybar_colors"
fi

if [[ -f "$rofi_colors" ]]; then
    tmp="$(mktemp "$WALLUST_DIR/.colors-rofi.rasi.nks.XXXXXX")"
    cp -f -- "$rofi_colors" "$tmp"
    sed -i \
        -e "s|^    foreground: .*|    foreground: $TEXT_HEX;|" \
        -e "s|^    text: .*|    text: $TEXT_HEX;|" \
        -e "s|^    text-invert: .*|    text-invert: $BG_HEX;|" \
        "$tmp"
    grep -q '^    text:' "$tmp" || sed -i "/^}/i\    text: $TEXT_HEX;\n    text-invert: $BG_HEX;" "$tmp"
    mv -f -- "$tmp" "$rofi_colors"
fi

if [[ -f "$hypr_colors" ]]; then
    tmp="$(mktemp "$WALLUST_DIR/.colors-hyprland.conf.nks.XXXXXX")"
    cp -f -- "$hypr_colors" "$tmp"
    sed -i -e "s|^\$foreground = rgb(.*)|\$foreground = rgb($TEXT_PLAIN)|" "$tmp"
    mv -f -- "$tmp" "$hypr_colors"
fi

foot_colors="$WALLUST_DIR/colors-foot.ini"
if [[ -f "$foot_colors" ]]; then
    tmp="$(mktemp "$WALLUST_DIR/.colors-foot.ini.nks.XXXXXX")"
    cp -f -- "$foot_colors" "$tmp"
    sed -i \
        -e "s|^foreground=.*|foreground=$TEXT_HEX|" \
        -e "s|^cursor=.*|cursor=$TEXT_HEX|" \
        "$tmp"
    mv -f -- "$tmp" "$foot_colors"
fi

kitty_colors="$WALLUST_DIR/colors-kitty.conf"
if [[ -f "$kitty_colors" ]]; then
    tmp="$(mktemp "$WALLUST_DIR/.colors-kitty.conf.nks.XXXXXX")"
    cp -f -- "$kitty_colors" "$tmp"
    sed -i \
        -e "s|^foreground .*|foreground $TEXT_HEX|" \
        -e "s|^cursor .*|cursor $TEXT_HEX|" \
        -e "s|^active_tab_foreground .*|active_tab_foreground $BG_HEX|" \
        -e "s|^active_tab_background .*|active_tab_background $TEXT_HEX|" \
        -e "s|^inactive_tab_foreground .*|inactive_tab_foreground $TEXT_HEX|" \
        -e "s|^inactive_tab_background .*|inactive_tab_background $BG_HEX|" \
        -e "s|^active_border_color .*|active_border_color $TEXT_HEX|" \
        -e "s|^inactive_border_color .*|inactive_border_color $BG_HEX|" \
        "$tmp"
    mv -f -- "$tmp" "$kitty_colors"
fi

for skin in "$HOME/.config/waybar/skins"/*; do
    [[ -d "$skin" ]] && publish_atomic "$waybar_colors" "$skin/colors-wallust.css" || true
done
for skin in "$HOME/.config/swaync/skins"/* "$HOME/.config/wlogout/skins"/*; do
    [[ -d "$skin" ]] && publish_atomic "$waybar_colors" "$skin/colors-wallust.css" || true
done
for skin in "$HOME/.config/rofi/skins"/*; do
    [[ -d "$skin" ]] && publish_atomic "$rofi_colors" "$skin/colors-wallust.rasi" || true
done

killall -q navbar-hover navbar-watcher waybar 2>/dev/null || true
swaync-client -rs 2>/dev/null || true

case "$MANAGEMENT_MODE" in
    static) waybar & ;;
    hover)  navbar-hover & ;;
    *)      navbar-watcher & ;;
esac
