#!/usr/bin/env bash
set -euo pipefail
quick-theme makima.mp4 clean clean minimal clean clean
printf '%s\n' makima-light > "${XDG_CACHE_HOME:-$HOME/.cache}/nekoroshell_palette"

bash "$HOME/.config/hypr/scripts/wallpapers/apply-makima-palette.sh" light
