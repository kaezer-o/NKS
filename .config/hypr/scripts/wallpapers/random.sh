#!/usr/bin/env bash
set -euo pipefail

WALLPAPERS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/wallpapers"
[[ -d "$WALLPAPERS_DIR" ]] || exit 0
find "$WALLPAPERS_DIR" -type f -print | shuf -n 1
