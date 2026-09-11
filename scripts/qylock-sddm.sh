#!/usr/bin/env bash
set -euo pipefail

repo='https://github.com/Darkkal44/qylock.git'
work="${XDG_CACHE_HOME:-$HOME/.cache}/nekoroshell/qylock"
system='/usr/share/sddm/themes'
confdir='/etc/sddm.conf.d'
conf="$confdir/theme.conf"

command -v sddm >/dev/null 2>&1 || { printf '%s\n' '[WARN] SDDM is not installed; skipping Qylock.' >&2; exit 0; }
command -v git >/dev/null 2>&1 || { printf '%s\n' '[WARN] git is not installed; skipping Qylock.' >&2; exit 0; }
sudo -v
rm -rf "$work"
git clone --depth=1 "$repo" "$work"

theme="$(find "$work/themes" -mindepth 1 -maxdepth 1 -type d -iname 'Forest' -print -quit 2>/dev/null || true)"
if [[ -z "$theme" ]]; then printf '%s\n' '[WARN] Qylock Forest theme not found; skipping Qylock.' >&2; exit 0; fi
sudo install -d "$system" "$confdir"
sudo rm -rf "$system/Forest"
sudo cp -a "$theme" "$system/Forest"
sudo chown -R root:root "$system/Forest"

if [[ -f "$conf" ]]; then
  if grep -q '^Current=' "$conf"; then
    sudo sed -i 's/^Current=.*/Current=Forest/' "$conf"
  elif grep -q '^\[Theme\]' "$conf"; then
    sudo sed -i '/^\[Theme\]/a Current=Forest' "$conf"
  else
    printf '\n[Theme]\nCurrent=Forest\n' | sudo tee -a "$conf" >/dev/null
  fi
else
  printf '[Theme]\nCurrent=Forest\n' | sudo tee "$conf" >/dev/null
fi
sudo systemctl enable sddm.service
