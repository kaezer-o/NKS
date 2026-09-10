#!/usr/bin/env bash
set -Eeuo pipefail

readonly QYLOCK_REPO="https://github.com/Darkkal44/qylock.git"
readonly WORK_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/nekoroshell/qylock"
readonly THEME_NAME="Forest"
readonly SYSTEM_THEMES_DIR="/usr/share/sddm/themes"
readonly SDDM_CONF_DIR="/etc/sddm.conf.d"
readonly SDDM_CONF="$SDDM_CONF_DIR/theme.conf"

info(){ printf '==> %s\n' "$*"; }
ok(){ printf '  [OK] %s\n' "$*"; }
die(){ printf '  [ERROR] %s\n' "$*" >&2; exit 1; }

[[ -r /etc/os-release ]] || die "/etc/os-release is missing."
# shellcheck disable=SC1091
source /etc/os-release
[[ "${ID:-}" == "arch" ]] || die "Qylock integration in NKS is supported on Arch Linux only."
command -v git >/dev/null 2>&1 || die "git is required."
command -v sudo >/dev/null 2>&1 || die "sudo is required for SDDM configuration."
command -v sddm >/dev/null 2>&1 || die "SDDM is not installed."
sudo -v

if [[ -d "$WORK_DIR/.git" ]]; then
    info "Updating Qylock"
    git -C "$WORK_DIR" fetch --depth=1 origin main
    git -C "$WORK_DIR" reset --hard origin/main
    git -C "$WORK_DIR" clean -fdx
else
    info "Downloading Qylock"
    rm -rf "$WORK_DIR"
    git clone --depth=1 "$QYLOCK_REPO" "$WORK_DIR"
fi

THEME_DIR="$(find "$WORK_DIR" -type d -iname "$THEME_NAME" -print -quit 2>/dev/null || true)"

[[ -n "$THEME_DIR" ]] || die "Qylock theme '$THEME_NAME' was not found in the downloaded repository."

info "Installing Qylock SDDM theme: $THEME_NAME"
sudo install -d "$SYSTEM_THEMES_DIR" "$SDDM_CONF_DIR"
sudo rm -rf "$SYSTEM_THEMES_DIR/$THEME_NAME"
sudo cp -a "$THEME_DIR" "$SYSTEM_THEMES_DIR/$THEME_NAME"
sudo chown -R root:root "$SYSTEM_THEMES_DIR/$THEME_NAME"

if [[ -f "$SDDM_CONF" ]]; then
    if grep -q '^Current=' "$SDDM_CONF"; then
        sudo sed -i "s|^Current=.*|Current=$THEME_NAME|" "$SDDM_CONF"
    elif grep -q '^\[Theme\]' "$SDDM_CONF"; then
        sudo sed -i "/^\[Theme\]/a Current=$THEME_NAME" "$SDDM_CONF"
    else
        printf '\n[Theme]\nCurrent=%s\n' "$THEME_NAME" | sudo tee -a "$SDDM_CONF" >/dev/null
    fi
else
    printf '[Theme]\nCurrent=%s\n' "$THEME_NAME" | sudo tee "$SDDM_CONF" >/dev/null
fi

sudo systemctl enable sddm.service
[[ -d "$SYSTEM_THEMES_DIR/$THEME_NAME" ]] || die "Qylock theme copy failed."

if command -v sddm-greeter >/dev/null 2>&1; then
    if sddm-greeter --test-mode --theme "$SYSTEM_THEMES_DIR/$THEME_NAME" >/tmp/nekoroshell-qylock-test.log 2>&1; then
        ok "Qylock SDDM greeter smoke test passed."
    else
        printf '  [WARN] Qylock theme was installed, but sddm-greeter smoke test reported an error.\n' >&2
        printf '  [WARN] Test log: /tmp/nekoroshell-qylock-test.log\n' >&2
    fi
fi

ok "Qylock SDDM theme '$THEME_NAME' installed and SDDM enabled."
