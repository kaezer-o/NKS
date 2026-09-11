#!/usr/bin/env bash
set -euo pipefail
quick-theme makima.mp4 crimson crimson legacy crimson crimson
printf '%s\n' makima-dark > "${XDG_CACHE_HOME:-$HOME/.cache}/nekoroshell_palette"

bash "$HOME/.config/hypr/scripts/wallpapers/apply-makima-palette.sh" dark
