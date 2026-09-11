#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/wallpapers"
CHOOSER="$SCRIPT_DIR/random.sh"
SETTER="$SCRIPT_DIR/set-wallpaper.sh"
WALL="$("$CHOOSER")"
[[ -n "$WALL" ]] || exit 0
exec "$SETTER" "$WALL"
