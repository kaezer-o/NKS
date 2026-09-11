#!/usr/bin/env bash
set -euo pipefail
mode="${1:-dark}"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/wallust"
mkdir -p "$cache"
if [[ "$mode" == dark ]]; then bg='#0B090A'; text='#F4F6F5'; accent='#D51F42'; soft='#F0D8DC'; inactive='#5F5558';
else bg='#F4EEEE'; text='#0B1111'; accent='#B91535'; soft='#671224'; inactive='#A97B84'; fi

write_atomic() {
  local target="$1" tmp
  tmp="$(mktemp "${target}.nks.XXXXXX")"
  cat > "$tmp"
  mv -f -- "$tmp" "$target"
}
write_atomic "$cache/colors-waybar.css" <<EOF2
@define-color background $bg;
@define-color foreground $text;
@define-color text $text;
@define-color text-invert $bg;
@define-color cursor $text;
@define-color color0 $bg;
@define-color color1 $accent;
@define-color color2 $accent;
@define-color color3 $soft;
@define-color color4 $text;
@define-color color5 $accent;
@define-color color6 $inactive;
@define-color color7 $text;
@define-color color8 $inactive;
@define-color color9 $accent;
@define-color color10 $text;
@define-color color11 $text;
@define-color color12 $soft;
@define-color color13 $text;
@define-color color14 $inactive;
@define-color color15 $text;
EOF2
write_atomic "$cache/colors-rofi.rasi" <<EOF2
* {
  background: $bg;
  foreground: $text;
  text: $text;
  text-invert: $bg;
  color0: $bg;
  color1: $accent;
  color3: $soft;
  color5: $accent;
  color8: $inactive;
  color13: $text;
  color15: $text;
  background-window: ${bg}EE;
  background-input: ${text}20;
}
EOF2
write_atomic "$cache/colors-kitty.conf" <<EOF2
foreground $text
background $bg
cursor $text
cursor_text_color $bg
color0 $inactive
color8 $soft
color1 $accent
color9 $accent
color2 $accent
color10 $text
color3 $soft
color11 $text
color4 $text
color12 $soft
color5 $accent
color13 $text
color6 $inactive
color14 $soft
color7 $text
color15 $text
EOF2
write_atomic "$cache/colors-hyprland.conf" <<EOF2
\$background = rgb(${bg#\#})
\$foreground = rgb(${text#\#})
\$inactive = rgb(${inactive#\#})
\$color0 = rgb(${bg#\#})
\$color1 = rgb(${accent#\#})
\$color5 = rgb(${accent#\#})
\$color13 = rgb(${text#\#})
EOF2
for d in "$HOME/.config/waybar/skins"/*; do [[ -d "$d" ]] && cp -f "$cache/colors-waybar.css" "$d/colors-wallust.css"; done
for d in "$HOME/.config/swaync/skins"/* "$HOME/.config/wlogout/skins"/*; do [[ -d "$d" ]] && cp -f "$cache/colors-waybar.css" "$d/colors-wallust.css"; done
for d in "$HOME/.config/rofi/skins"/*; do [[ -d "$d" ]] && cp -f "$cache/colors-rofi.rasi" "$d/colors-wallust.rasi"; done
