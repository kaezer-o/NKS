#!/usr/bin/env bash
set -Eeuo pipefail

readonly NKS_VERSION="1.6-standalone"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
readonly BACKUP_DIR_NAME="NeKoRoSHELL-backups"
readonly CONFIGS=(btop cava fastfetch hypr kitty ohmyposh rofi swaync wallpapers wallust waybar wlogout themes)

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

TARGET_HOME=""
OS_ID=""
AUR_HELPER=""
USER_BIN_DIR=""
BACKUP_ARCHIVE=""
REPLACEMENT_MODE=0
NO_CONFIRM=0
CLI_USER=""

if [[ "$EUID" -eq 0 && -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    TARGET_USER="$SUDO_USER"
else
    TARGET_USER="${USER:-}"
fi
DRY_RUN=0
MOVED_TARGETS=()
DEPLOY_STAGE=""

log_info() { printf '%b==> %s%b\n' "$BLUE" "$*" "$NC"; }
log_ok()   { printf '  %b[OK]%b %s\n' "$GREEN" "$NC" "$*"; }
log_warn() { printf '  %b[WARN]%b %s\n' "$YELLOW" "$NC" "$*"; }
log_err()  { printf '%b[ERROR]%b %s\n' "$RED" "$NC" "$*" >&2; }
die() { log_err "$*"; exit 1; }

run() {
    if (( DRY_RUN )); then
        printf '  %b[DRY-RUN]%b' "$BLUE" "$NC"
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}

usage() {
    cat <<USAGE
NeKoRoSHELL ${NKS_VERSION}

Usage:
  ./install.sh [--replace-existing] [--no-confirm] [--user USER] [--dry-run]

Modes:
  default             Fresh/clean Arch installation.
  --replace-existing  Replace an existing desktop/dotfiles configuration after backup.
  --no-confirm        Suppress confirmation prompts for package/AUR transactions. Does not authorize replacing an existing desktop; combine with --replace-existing for that.
  --user USER         Select the normal user account when multiple accounts are present.
  --dry-run           Show actions without changing the system.

This installer is intentionally Arch-only. It installs the current Arch repository
Hyprland package, NKS runtime dependencies, Qylock SDDM integration (SDDM only),
and deploys the standalone Lua configuration.
USAGE
}

parse_args() {
    while (($#)); do
        case "$1" in
            --replace-existing) REPLACEMENT_MODE=1 ;;
            --no-confirm|-y) NO_CONFIRM=1 ;;
            --user)
                (($# >= 2)) || die "--user requires a username."
                CLI_USER="$2"
                shift
                ;;
            --dry-run|-d) DRY_RUN=1 ;;
            --help|-h) usage; exit 0 ;;
            *) die "Unknown argument: $1" ;;
        esac
        shift
    done
    if [[ -n "$CLI_USER" ]]; then
        TARGET_USER="$CLI_USER"
    fi
}

find_human_user() {
    local -a candidates=()
    local entry username uid home shell

    if [[ "${TARGET_USER:-}" != "" && "${TARGET_USER}" != "root" ]] && id -u "$TARGET_USER" >/dev/null 2>&1; then
        TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
        [[ -n "$TARGET_HOME" && -d "$TARGET_HOME" ]] && return 0
    fi

    while IFS=: read -r username _ uid _ _ home shell; do
        [[ "$username" != "root" ]] || continue
        [[ "$uid" =~ ^[0-9]+$ ]] || continue
        (( uid >= 1000 && uid < 60000 )) || continue
        [[ "$home" == /home/* ]] || continue
        [[ -d "$home" ]] || continue
        candidates+=("$username")
    done < /etc/passwd

    if ((${#candidates[@]} == 0)); then
        die "No normal user account with a /home directory was found. Run archinstall, create the normal user, enable sudo/wheel access, then rerun NeKoRoSHELL."
    fi

    if ((${#candidates[@]} == 1)); then
        TARGET_USER="${candidates[0]}"
        TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
        log_ok "Detected normal user: $TARGET_USER ($TARGET_HOME)"
        return 0
    fi

    if (( NO_CONFIRM )); then
        die "Multiple normal user accounts were found. Use --user USER with --no-confirm so NKS does not guess the target account."
    fi

    log_warn "Multiple normal users were found. Choose the account that should own the NKS desktop."
    select username in "${candidates[@]}"; do
        [[ -n "${username:-}" ]] || continue
        TARGET_USER="$username"
        TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
        break
    done
}

reexec_as_user() {
    if [[ "$EUID" -eq 0 ]]; then
        [[ "$TARGET_USER" != "root" ]] || die "A non-root desktop user is required. Run archinstall to create one."
        if (( DRY_RUN )); then
            log_info "Dry-run: staying as root temporarily; no user/system changes will be executed."
            return 0
        fi
        command -v sudo >/dev/null 2>&1 || { log_info "sudo is missing; installing it before dropping to the detected user..."; pacman -Syu --needed --noconfirm sudo; }
        id -u "$TARGET_USER" >/dev/null 2>&1 || die "Unable to resolve target user '$TARGET_USER'. Run archinstall to create the user."

        # An Arch installation using archinstall normally configures wheel/sudo. Do not
        # silently edit sudoers here; instead, verify the user can elevate when needed.
        if ! sudo -n -u "$TARGET_USER" true 2>/dev/null; then
            log_info "Re-entering installer as $TARGET_USER. sudo may ask for the account password when system packages are installed."
        fi
        exec sudo -iu "$TARGET_USER" -- bash "$SCRIPT_DIR/install.sh" "$@"
    fi
}

detect_os() {
    [[ -r /etc/os-release ]] || die "/etc/os-release is missing. This installer requires Arch Linux."
    # shellcheck disable=SC1091
    source /etc/os-release
    OS_ID="${ID:-}"
    [[ "$OS_ID" == "arch" ]] || die "Unsupported OS '$OS_ID'. This standalone installer targets Arch Linux only."
    command -v pacman >/dev/null 2>&1 || die "pacman was not found."
    log_ok "Detected Arch Linux."
}

ensure_runtime_user() {
    find_human_user
    [[ "$TARGET_HOME" == /home/* ]] || die "The selected user's home directory is invalid: $TARGET_HOME"
    [[ "$(id -u "$TARGET_USER")" -ge 1000 ]] || die "The target account must be a normal non-root user."
    USER_BIN_DIR="$TARGET_HOME/.local/bin/nekoroshell"
    if (( DRY_RUN )); then
        log_info "Dry-run: would prepare $TARGET_HOME/.local/bin and $TARGET_HOME/.cache/nekoroshell for $TARGET_USER."
        return 0
    fi
    mkdir -p "$TARGET_HOME/.local/bin" "$TARGET_HOME/.cache/nekoroshell"
    chown -R "$TARGET_USER":"$(id -gn "$TARGET_USER")" "$TARGET_HOME/.local/bin" "$TARGET_HOME/.cache/nekoroshell" 2>/dev/null || true
}

require_user_sudo() {
    if (( DRY_RUN )); then
        log_info "Dry-run: skipping sudo credential validation."
        return 0
    fi
    command -v sudo >/dev/null 2>&1 || die "sudo is required for system package/service changes. Install/configure sudo for $TARGET_USER (normally via archinstall), then rerun."
    sudo -v
    sudo -n true >/dev/null 2>&1 || true
}

check_existing_frameworks() {
    local found=0
    if [[ -f "$TARGET_HOME/.config/hypr/conf/keybindings/default.lua" ]]; then
        log_warn "An existing Hyprland/dotfiles framework configuration was detected. Standalone mode must not let two desktop frameworks own the same active Hyprland configuration."
        found=1
    fi
    if [[ -f "$TARGET_HOME/.config/hypr/hyprland.conf" ]]; then
        log_warn "Legacy hyprland.conf exists; Hyprland 0.55+ uses hyprland.lua."
        found=1
    fi
    if ((found)) && ((REPLACEMENT_MODE == 0)); then
        die "Existing desktop configuration detected. Re-run with --replace-existing after confirming you want NKS to become the active compositor configuration. The installer will create a backup first."
    fi
}

install_official_packages() {
    local pkg_file="$SCRIPT_DIR/packages/pkglist-arch.txt"
    [[ -f "$pkg_file" ]] || die "Missing package manifest: $pkg_file"

    mapfile -t packages < <(grep -Ev '^\s*(#|$)' "$pkg_file")
    ((${#packages[@]})) || die "The Arch package manifest is empty."

    log_info "Synchronizing Arch repositories and installing official NKS packages."
    log_info "Hyprland is installed here by NKS; the installer does not assume it already exists."
    if (( NO_CONFIRM )); then
        run sudo pacman -Syu --needed --noconfirm "${packages[@]}"
    else
        run sudo pacman -Syu --needed "${packages[@]}"
    fi

    if (( DRY_RUN )); then
        log_ok "Official package installation would be performed."
        return 0
    fi

    command -v hyprland >/dev/null 2>&1 || die "Hyprland was not installed successfully."
    command -v sddm >/dev/null 2>&1 || die "SDDM was not installed successfully."
    log_ok "Official package installation completed."
}

configure_networking() {
    if (( DRY_RUN )); then
        log_info "Would enable NetworkManager when no conflicting network manager is active."
        return 0
    fi

    if systemctl is-active --quiet NetworkManager.service || systemctl is-enabled --quiet NetworkManager.service; then
        log_ok "NetworkManager is already enabled/active."
        return 0
    fi

    # Do not silently disable or replace another network stack. On a minimal
    # archinstall system there is normally no competing network manager, so
    # enabling NetworkManager is the expected standalone path.
    if systemctl is-active --quiet systemd-networkd.service || systemctl is-enabled --quiet systemd-networkd.service; then
        log_warn "systemd-networkd is already active/enabled; leaving it untouched. NKS will still install the NetworkManager applet, but nm-applet requires NetworkManager."
        return 0
    fi
    if systemctl is-active --quiet iwd.service || systemctl is-enabled --quiet iwd.service; then
        log_warn "iwd is already active/enabled; leaving it untouched. NKS will still install the NetworkManager applet, but nm-applet requires NetworkManager."
        return 0
    fi

    sudo systemctl enable --now NetworkManager.service
    log_ok "NetworkManager enabled and started."
}

_gpu_lspci_lines() {
    lspci -nn 2>/dev/null | grep -Ei 'VGA compatible controller|3D controller|Display controller' || true
}

configure_graphics() {
    local lines line nvidia_found=0 intel_found=0 amd_found=0
    local open_nvidia=0 legacy_580=0 unknown_nvidia=0
    local -a gpu_packages=()
    lines="$(_gpu_lspci_lines)"

    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        case "${line,,}" in
            *nvidia*)
                nvidia_found=1
                case "${line,,}" in
                    *"rtx 20"*|*"rtx 30"*|*"rtx 40"*|*"rtx 50"*|*"gtx 16"*|*"t4"*|*"a100"*|*"a10"*|*"a16"*|*"a2"*|*"a30"*|*"a40"*|*"a800"*|*"h100"*|*"h200"*|*"h800"*|*"l4"*|*"l40"*|*"l40s"*|*"rtx pro"*)
                        open_nvidia=1 ;;
                    *"gtx 10"*|*"gt 10"*|*"gtx 9"*|*"gt 9"*|*"gtx 750"*|*"quadro m"*|*"quadro p"*|*"tesla p"*|*"tesla v"*|*"titan v"*|*"titan xp"*)
                        legacy_580=1 ;;
                    *)
                        unknown_nvidia=1 ;;
                esac
                ;;
            *"intel"*) intel_found=1 ;;
            *"amd"*|*"advanced micro devices"*|*"ati technologies"*) amd_found=1 ;;
            *) ;;
        esac
    done <<< "$lines"

    if (( nvidia_found == 0 && intel_found == 0 && amd_found == 0 )); then
        log_warn "No Intel/AMD/NVIDIA GPU was positively identified. Keeping generic Mesa support and continuing."
        if (( DRY_RUN )); then
            log_info "Would record the generic GPU profile and detected PCI display-controller lines."
        else
            printf 'generic\n' > "$TARGET_HOME/.cache/nekoroshell/gpu-profile"
            printf '%s\n' "${lines:-No PCI display controller lines detected.}" > "$TARGET_HOME/.cache/nekoroshell/detected-gpus.txt"
        fi
        return 0
    fi

    (( intel_found )) && log_ok "Intel graphics detected."
    (( amd_found )) && log_ok "AMD graphics detected."
    (( nvidia_found )) && log_ok "NVIDIA graphics detected."

    if (( nvidia_found )); then
        if (( open_nvidia && legacy_580 )); then
            log_warn "Mixed modern and Maxwell/Pascal/Volta NVIDIA generations detected. NKS will not install conflicting proprietary driver families automatically; using nouveau fallback."
            gpu_packages+=(vulkan-nouveau)
        elif (( unknown_nvidia && !open_nvidia && !legacy_580 )); then
            log_warn "NVIDIA GPU generation could not be classified safely. Using nouveau fallback instead of risking an incompatible proprietary driver."
            gpu_packages+=(vulkan-nouveau)
        elif (( open_nvidia )); then
            if pacman -Q linux >/dev/null 2>&1 && ! has_nonstandard_kernel; then
                gpu_packages+=(nvidia-open nvidia-prime)
            else
                gpu_packages+=(nvidia-open-dkms dkms nvidia-prime)
                add_kernel_headers_to_array gpu_packages
            fi
            log_ok "Selected the current NVIDIA open kernel-module driver for the detected modern NVIDIA GPU."
        elif (( legacy_580 )); then
            gpu_packages+=(dkms)
            add_kernel_headers_to_array gpu_packages
            log_ok "Selected the current Arch-supported NVIDIA 580xx DKMS driver for Maxwell/Pascal/Volta."
        fi
    fi

    # Install kernel/module prerequisites before any DKMS AUR build.
    if ((${#gpu_packages[@]})); then
        mapfile -t gpu_packages < <(printf '%s\n' "${gpu_packages[@]}" | awk 'NF && !seen[$0]++')
        if (( NO_CONFIRM )); then
            run sudo pacman -S --needed --noconfirm "${gpu_packages[@]}"
        else
            run sudo pacman -S --needed "${gpu_packages[@]}"
        fi
    fi

    if (( ! DRY_RUN )) && (( nvidia_found )) && ((${#gpu_packages[@]})) && printf '%s\n' "${gpu_packages[@]}" | grep -Eq '(^|[[:space:]])(dkms|nvidia-open-dkms)([[:space:]]|$)'; then
        local running_kernel_build="/usr/lib/modules/$(uname -r)/build"
        if [[ ! -e "$running_kernel_build" ]]; then
            die "A DKMS-based NVIDIA driver is required, but kernel build files are missing for $(uname -r). Install the matching kernel headers, then rerun NKS."
        fi
    fi

    if (( nvidia_found && legacy_580 && !open_nvidia )); then
        ensure_aur_helper
        if (( DRY_RUN )); then
            log_info "Would install AUR package: nvidia-580xx-dkms"
        elif (( NO_CONFIRM )); then
            run "$AUR_HELPER" -S --needed --noconfirm nvidia-580xx-dkms
        else
            run "$AUR_HELPER" -S --needed nvidia-580xx-dkms
        fi
    fi

    local profile="generic"
    if (( nvidia_found )); then
        if (( open_nvidia && !legacy_580 && !unknown_nvidia )); then
            profile="nvidia-modern"
        elif (( legacy_580 && !open_nvidia && !unknown_nvidia )); then
            profile="nvidia-580xx"
        elif (( unknown_nvidia || (open_nvidia && legacy_580) )); then
            profile="nvidia-nouveau"
        else
            profile="nvidia-modern"
        fi
    elif (( amd_found && intel_found )); then
        profile="hybrid-intel-amd"
    elif (( amd_found )); then
        profile="amd"
    elif (( intel_found )); then
        profile="intel"
    fi

    if (( DRY_RUN )); then
        log_info "Detected GPU profile would be: $profile"
    else
        printf '%s\n' "${lines:-No PCI display controller lines detected.}" > "$TARGET_HOME/.cache/nekoroshell/detected-gpus.txt"
        printf '%s\n' "$profile" > "$TARGET_HOME/.cache/nekoroshell/gpu-profile"
    fi
}

has_nonstandard_kernel() {
    local k
    for k in linux-zen linux-lts linux-hardened; do
        pacman -Q "$k" >/dev/null 2>&1 && return 0
    done
    return 1
}

add_kernel_headers_to_array() {
    local -n _arr=$1
    local k
    for k in linux linux-zen linux-lts linux-hardened; do
        if pacman -Q "$k" >/dev/null 2>&1; then
            case "$k" in
                linux) _arr+=(linux-headers) ;;
                linux-zen) _arr+=(linux-zen-headers) ;;
                linux-lts) _arr+=(linux-lts-headers) ;;
                linux-hardened) _arr+=(linux-hardened-headers) ;;
            esac
        fi
    done
}

detect_connected_outputs() {
    local status base output
    for status in /sys/class/drm/card*-*/status; do
        [[ -f "$status" ]] || continue
        [[ "$(cat "$status" 2>/dev/null || true)" == "connected" ]] || continue
        base="$(basename "$(dirname "$status")")"
        output="${base#*-}"
        case "$output" in
            eDP-*|HDMI-*|DP-*|DVI-*|VGA-*|USB-C-*|DisplayPort-*) printf '%s\n' "$output" ;;
        esac
    done | awk 'NF && !seen[$0]++'
}

generate_hardware_lua() {
    local out="$TARGET_HOME/.config/hypr/hardware.lua"
    local profile="generic"
    [[ -f "$TARGET_HOME/.cache/nekoroshell/gpu-profile" ]] && profile="$(cat "$TARGET_HOME/.cache/nekoroshell/gpu-profile")"
    if (( DRY_RUN )); then
        log_info "Would generate $out for GPU profile: $profile and connected display outputs."
        return 0
    fi

    mapfile -t connected_outputs < <(detect_connected_outputs)
    {
        printf '%s\n' '-- Auto-generated by NeKoRoSHELL. Do not edit manually.'
        printf '%s\n' '-- Hardware and connected-monitor information is regenerated by the installer.'
        case "$profile" in
            nvidia-modern|nvidia-580xx)
                printf '%s\n' 'hl.env("LIBVA_DRIVER_NAME", "nvidia")'
                printf '%s\n' 'hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")'
                ;;
            *)
                printf '%s\n' '-- No NVIDIA-specific compositor environment is required.'
                ;;
        esac
        if ((${#connected_outputs[@]})); then
            printf '%s\n' '-- Connected DRM outputs detected during installation.'
            local output
            for output in "${connected_outputs[@]}"; do
                printf 'hl.monitor({ output = %q, mode = "preferred", position = "auto", scale = 1 })\n' "$output"
            done
        else
            printf '%s\n' '-- No connected DRM output was detected. The main configuration supplies a generic preferred-mode fallback.'
        fi
    } > "$out"
    chown "$TARGET_USER":"$(id -gn "$TARGET_USER")" "$out"
    chmod 0644 "$out"

    if ((${#connected_outputs[@]})); then
        printf '%s\n' "${connected_outputs[@]}" > "$TARGET_HOME/.cache/nekoroshell/connected-monitors.txt"
        chown "$TARGET_USER":"$(id -gn "$TARGET_USER")" "$TARGET_HOME/.cache/nekoroshell/connected-monitors.txt"
        log_ok "Generated display profile: ${connected_outputs[*]}"
    else
        printf '%s\n' 'none-detected' > "$TARGET_HOME/.cache/nekoroshell/connected-monitors.txt"
        chown "$TARGET_USER":"$(id -gn "$TARGET_USER")" "$TARGET_HOME/.cache/nekoroshell/connected-monitors.txt"
        log_warn "No connected DRM display output was detected during installation; Hyprland will use its preferred-mode fallback."
    fi
    log_ok "Generated hardware profile: $profile"
}

ensure_aur_helper() {
    if command -v paru >/dev/null 2>&1; then AUR_HELPER=paru; log_ok "Using existing AUR helper: paru"; return 0; fi
    if command -v yay >/dev/null 2>&1; then AUR_HELPER=yay; log_ok "Using existing AUR helper: yay"; return 0; fi

    if (( DRY_RUN )); then
        AUR_HELPER=yay
        log_info "No AUR helper detected; would install yay from the AUR as the normal user."
        return 0
    fi

    command -v git >/dev/null 2>&1 || die "git is missing; it should have been installed from the official package manifest."
    command -v makepkg >/dev/null 2>&1 || die "makepkg is missing; base-devel is required."

    local build_root="$TARGET_HOME/.cache/nekoroshell/yay-build"
    run rm -rf "$build_root"
    run mkdir -p "$build_root"
    log_info "Installing yay as the normal user (AUR build tools must not run as root)."
    git clone --depth=1 https://aur.archlinux.org/yay.git "$build_root/yay"
    (cd "$build_root/yay" && makepkg -si --noconfirm)
    command -v yay >/dev/null 2>&1 || die "yay installation failed."
    AUR_HELPER=yay
}

install_aur_packages() {
    local pkg_file="$SCRIPT_DIR/packages/aurpkglist-arch.txt"
    [[ -f "$pkg_file" ]] || die "Missing AUR manifest: $pkg_file"
    mapfile -t packages < <(grep -Ev '^\s*(#|$)' "$pkg_file")
    ((${#packages[@]})) || return 0

    ensure_aur_helper
    log_info "Installing NKS packages that are not provided by the official Arch repositories."
    if (( NO_CONFIRM )); then
        run "$AUR_HELPER" -S --needed --noconfirm "${packages[@]}"
    else
        run "$AUR_HELPER" -S --needed "${packages[@]}"
    fi
}

install_zsh_and_shell() {
    local zshrc="$TARGET_HOME/.zshrc"
    local omp_config="$TARGET_HOME/.config/ohmyposh/zen.omp.json"
    local block_start="# --- NeKoRoSHELL START ---"
    local block_end="# --- NeKoRoSHELL END ---"

    if (( ! DRY_RUN )); then
        touch "$zshrc"
        sed -i "/${block_start}/,/${block_end}/d" "$zshrc"
        cat >> "$zshrc" <<'RC'

# --- NeKoRoSHELL START ---
export PATH="$HOME/.local/bin/nekoroshell:$HOME/.local/bin:$HOME/.cargo/bin:$HOME/go/bin:$PATH"

# Fast, portable Zsh enhancements from official Arch packages.
[[ -r /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
  source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -r /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
  source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Zen-style prompt using Oh My Posh; configuration is owned by NKS.
if command -v oh-my-posh >/dev/null 2>&1; then
  eval "$(oh-my-posh init zsh --config \"$HOME/.config/ohmyposh/zen.omp.json\")"
fi
# --- NeKoRoSHELL END ---
RC
        chmod 0644 "$zshrc"
        if [[ -x /usr/bin/zsh ]]; then
            sudo usermod -s /usr/bin/zsh "$TARGET_USER"
        fi
    else
        log_info "Would configure Zsh autosuggestions, syntax highlighting, and the NKS Zen prompt."
    fi
}


install_home_files() {
    local -a files=(
        "home/.face.icon"
        "home/change-avatar.sh"
    )
    local file
    for file in "${files[@]}"; do
        [[ -f "$SCRIPT_DIR/$file" ]] || continue
        run cp "$SCRIPT_DIR/$file" "$TARGET_HOME/$(basename "$file")"
    done
    if (( ! DRY_RUN )); then
        chmod +x "$TARGET_HOME/change-avatar.sh" 2>/dev/null || true
    fi
    log_ok "Home-directory support files staged."
}

create_backup() {
    local backup_root="$TARGET_HOME/$BACKUP_DIR_NAME"
    run mkdir -p "$backup_root"
    BACKUP_ARCHIVE="$backup_root/nekoroshell-$TIMESTAMP.tar.gz"

    local -a backup_items=()
    local item
    for item in "${CONFIGS[@]}"; do
        [[ -e "$TARGET_HOME/.config/$item" ]] && backup_items+=(".config/$item")
    done
    for item in .bashrc .zshrc .face.icon change-avatar.sh; do
        [[ -e "$TARGET_HOME/$item" ]] && backup_items+=("$item")
    done
    [[ -e "$TARGET_HOME/.local/bin/nekoroshell" ]] && backup_items+=(".local/bin/nekoroshell")

    if ((${#backup_items[@]})); then
        run tar -czf "$BACKUP_ARCHIVE" -C "$TARGET_HOME" "${backup_items[@]}"
        if (( DRY_RUN )); then
            log_ok "Would create backup: $BACKUP_ARCHIVE"
        else
            log_ok "Backup created: $BACKUP_ARCHIVE"
        fi
    else
        log_ok "No existing NKS-managed files needed a backup."
    fi
}

validate_source_tree() {
    local path
    local -a required_files=(
        ".config/hypr/hyprland.lua"
        ".config/hypr/hypridle.conf"
        ".config/hypr/hyprlock.conf"
        ".config/hypr/hyprsunset.conf"
        ".config/waybar/config.jsonc"
        ".config/waybar/style.css"
        ".config/rofi/config.rasi"
        ".config/swaync/config.json"
        ".config/swaync/style.css"
        ".config/wlogout/layout"
        ".config/wlogout/style.css"
        ".config/wallust/wallust-dark.toml"
        ".config/wallust/wallust-light.toml"
        "packages/pkglist-arch.txt"
        "packages/aurpkglist-arch.txt"
        "Makefile"
        "bin/customize"
        "bin/quick-theme"
        "bin/start-navbar"
        "bin/nks-gpu-info"
        "bin/nks-open-file-manager"
        "scripts/qylock-sddm.sh"
        "home/.face.icon"
        "home/change-avatar.sh"
    )
    local -a required_dirs=(
        ".config/hypr/hyprlock/skins"
        ".config/hypr/nks-window-skins"
        ".config/hypr/scripts/wallpapers"
        ".config/waybar/skins"
        ".config/rofi/skins"
        ".config/swaync/skins"
        ".config/wlogout/skins"
        ".config/themes"
        ".config/wallpapers"
        "home"
        "src"
    )

    for path in "${required_files[@]}"; do
        [[ -f "$SCRIPT_DIR/$path" ]] || die "Required repository file is missing: $path"
    done
    for path in "${required_dirs[@]}"; do
        [[ -d "$SCRIPT_DIR/$path" ]] || die "Required repository directory is missing: $path"
    done

    [[ -f "$SCRIPT_DIR/.config/wallpapers/makima.mp4" ]] || die "Bundled Makima wallpaper is missing."
    [[ -f "$SCRIPT_DIR/.config/themes/makima/makima.sh" ]] || die "Makima theme entrypoint is missing."
    [[ -f "$SCRIPT_DIR/.config/hypr/hyprlock/skins/makima/makima.conf" ]] || die "Makima Hyprlock skin is missing."
    [[ -f "$SCRIPT_DIR/.config/hypr/scripts/wallpapers/apply-makima-palette.sh" ]] || die "Makima palette helper is missing."

    mapfile -t official_pkgs < <(grep -Ev '^\s*(#|$)' "$SCRIPT_DIR/packages/pkglist-arch.txt")
    mapfile -t aur_pkgs < <(grep -Ev '^\s*(#|$)' "$SCRIPT_DIR/packages/aurpkglist-arch.txt")
    ((${#official_pkgs[@]})) || die "The official Arch package manifest is empty."
    ((${#aur_pkgs[@]})) || die "The AUR package manifest is empty."
    if printf '%s\n' "${official_pkgs[@]}" | grep -Fxq 'awww-git'; then
        die "AUR package 'awww-git' must not appear in the official package manifest."
    fi
    if printf '%s\n' "${aur_pkgs[@]}" | grep -Fxq 'hyprland'; then
        die "Official package 'hyprland' must not appear in the AUR manifest."
    fi
}

prepare_stage() {
    DEPLOY_STAGE="$TARGET_HOME/.cache/nekoroshell/.install-stage-$TIMESTAMP"
    run rm -rf "$DEPLOY_STAGE"
    run mkdir -p "$DEPLOY_STAGE/old" "$DEPLOY_STAGE/config"

    local conf
    for conf in "${CONFIGS[@]}"; do
        [[ -e "$SCRIPT_DIR/.config/$conf" ]] || continue
        run cp -a "$SCRIPT_DIR/.config/$conf" "$DEPLOY_STAGE/config/"
    done

    run mkdir -p "$DEPLOY_STAGE/config/hypr"
    run chmod -R u+rwX "$DEPLOY_STAGE/config"
    log_ok "Configuration staged before replacement."
}

rollback_deploy() {
    local conf
    for ((i=${#MOVED_TARGETS[@]}-1; i>=0; i--)); do
        conf="${MOVED_TARGETS[$i]}"
        rm -rf "$TARGET_HOME/.config/$conf" 2>/dev/null || true
        if [[ -e "$DEPLOY_STAGE/old/$conf" ]]; then
            mv "$DEPLOY_STAGE/old/$conf" "$TARGET_HOME/.config/$conf" 2>/dev/null || true
        fi
    done
    MOVED_TARGETS=()
}

atomic_deploy() {
    prepare_stage
    local conf
    [[ -d "$TARGET_HOME/.config" ]] || run mkdir -p "$TARGET_HOME/.config"

    for conf in "${CONFIGS[@]}"; do
        [[ -e "$DEPLOY_STAGE/config/$conf" ]] || continue
        if [[ -e "$TARGET_HOME/.config/$conf" ]]; then
            if ! run mv "$TARGET_HOME/.config/$conf" "$DEPLOY_STAGE/old/$conf"; then
                rollback_deploy
                die "Deployment failed while staging the existing .config/$conf. Backup and rollback were attempted."
            fi
        fi
        if ! run mv "$DEPLOY_STAGE/config/$conf" "$TARGET_HOME/.config/$conf"; then
            if [[ -e "$DEPLOY_STAGE/old/$conf" ]]; then
                mv "$DEPLOY_STAGE/old/$conf" "$TARGET_HOME/.config/$conf" 2>/dev/null || true
            fi
            rollback_deploy
            die "Deployment failed while replacing .config/$conf. Backup and rollback were attempted."
        fi
        MOVED_TARGETS+=("$conf")
    done

    local deployed_conf
    for deployed_conf in "${CONFIGS[@]}"; do
        [[ -e "$TARGET_HOME/.config/$deployed_conf" ]] && run chown -R "$TARGET_USER":"$(id -gn "$TARGET_USER")" "$TARGET_HOME/.config/$deployed_conf"
    done
    run chown -R "$TARGET_USER":"$(id -gn "$TARGET_USER")" "$TARGET_HOME/.cache/nekoroshell"
    MOVED_TARGETS=()
    run rm -rf "$DEPLOY_STAGE"
    log_ok "NKS configuration deployment completed."
}

install_binaries() {
    local bin_dir="$TARGET_HOME/.local/bin/nekoroshell"
    run mkdir -p "$bin_dir"
    run cp -a "$SCRIPT_DIR/bin/." "$bin_dir/"
    run chmod +x "$bin_dir"/* 2>/dev/null || true

    log_info "Compiling NKS native helper daemons."
    if (( DRY_RUN )); then
        log_info "Would run make -j$(nproc) and install the resulting binaries into $bin_dir."
        return 0
    fi
    command -v make >/dev/null 2>&1 || die "make is missing."
    command -v g++ >/dev/null 2>&1 || die "g++ is missing."
    command -v pkg-config >/dev/null 2>&1 || die "pkg-config is missing."
    pkg-config --exists wayland-client || die "Wayland client development files are missing."
    [[ -f /usr/include/nlohmann/json.hpp ]] || die "nlohmann/json.hpp is missing. Install the official Arch package: nlohmann-json."
    (cd "$SCRIPT_DIR" && make clean && make -j"$(nproc)")
    cp -a "$SCRIPT_DIR/build/." "$bin_dir/"
    chmod +x "$bin_dir"/* 2>/dev/null || true
    chown -R "$TARGET_USER":"$(id -gn "$TARGET_USER")" "$bin_dir"
    log_ok "Native helper daemons compiled and installed."
}

finalize_paths_and_permissions() {
    run mkdir -p "$TARGET_HOME/.local/share" "$TARGET_HOME/.cache/wallust" "$TARGET_HOME/.cache/nekoroshell"
    run find "$TARGET_HOME/.config" "$USER_BIN_DIR" -type f -name '*.sh' -exec chmod +x {} + 2>/dev/null || true

    # Ensure the NKS-installed scripts are the ones referenced by PATH first.
    if (( ! DRY_RUN )); then
        cat > "$TARGET_HOME/.local/bin/nks-env" <<'ENV'
#!/usr/bin/env bash
export PATH="$HOME/.local/bin/nekoroshell:$HOME/.local/bin:$HOME/.cargo/bin:$HOME/go/bin:$PATH"
ENV
        chmod +x "$TARGET_HOME/.local/bin/nks-env"
        chown "$TARGET_USER":"$(id -gn "$TARGET_USER")" "$TARGET_HOME/.local/bin/nks-env"
    fi
}

verify_hyprland_version() {
    local version major minor
    version="$(hyprland --version 2>/dev/null | head -n1 || true)"
    [[ -n "$version" ]] || die "Unable to query the installed Hyprland version."
    log_ok "$version"
    major="$(sed -n 's/.*Hyprland \([0-9][0-9]*\)\.\([0-9][0-9]*\).*/\1/p' <<<"$version")"
    minor="$(sed -n 's/.*Hyprland \([0-9][0-9]*\)\.\([0-9][0-9]*\).*/\2/p' <<<"$version")"
    [[ -n "$major" && -n "$minor" ]] || die "Unable to parse the Hyprland version."
    (( major > 0 || minor >= 55 )) || die "NeKoRoSHELL standalone requires Hyprland 0.55+ because it uses the Lua configuration API."
}

verify_graphics_stack() {
    local profile="generic"
    [[ -f "$TARGET_HOME/.cache/nekoroshell/gpu-profile" ]] && profile="$(cat "$TARGET_HOME/.cache/nekoroshell/gpu-profile")"
    log_info "Verifying graphics stack: $profile"
    case "$profile" in
        nvidia-modern)
            if pacman -Q nvidia-open >/dev/null 2>&1 || pacman -Q nvidia-open-dkms >/dev/null 2>&1; then
                log_ok "NVIDIA modern driver package is installed. DRM/KMS will be verified after reboot."
            else
                die "NVIDIA modern driver was selected but no nvidia-open package is installed."
            fi
            ;;
        nvidia-580xx)
            pacman -Q nvidia-580xx-dkms >/dev/null 2>&1 || die "NVIDIA 580xx DKMS driver was selected but is not installed."
            log_ok "NVIDIA 580xx DKMS driver is installed. DRM/KMS will be verified after reboot."
            ;;
        nvidia-nouveau)
            pacman -Q vulkan-nouveau >/dev/null 2>&1 || die "NVIDIA fallback selected but vulkan-nouveau is missing."
            log_ok "NVIDIA nouveau fallback is installed."
            ;;
        intel|hybrid-intel-amd)
            pacman -Q vulkan-intel >/dev/null 2>&1 || die "Intel graphics detected but vulkan-intel is missing."
            log_ok "Intel Mesa/Vulkan stack is installed."
            ;;
        amd)
            pacman -Q vulkan-radeon >/dev/null 2>&1 || die "AMD graphics detected but vulkan-radeon is missing."
            log_ok "AMD Mesa/Vulkan stack is installed."
            ;;
    esac
}

verify_display_stack() {
    log_info "Verifying display stack."
    local drm_devices=() driver_lines
    shopt -s nullglob
    for d in /sys/class/drm/card*-eDP-* /sys/class/drm/card*-HDMI-* /sys/class/drm/card*-DP-* /sys/class/drm/card*-DVI-* /sys/class/drm/card*-VGA-*; do
        [[ -e "$d" ]] || continue
        drm_devices+=("$d")
    done
    shopt -u nullglob

    if ((${#drm_devices[@]})); then
        log_ok "DRM display connectors are present."
        for d in "${drm_devices[@]}"; do
            local name status
            name="$(basename "$d")"
            status="$(cat "$d/status" 2>/dev/null || echo unknown)"
            printf '    %s: %s\n' "$name" "$status"
        done
    else
        log_warn "No DRM connector entries were found. This can occur in an unusual installation environment; verify with 'ls /sys/class/drm' after reboot."
    fi

    driver_lines="$(lspci -k 2>/dev/null | grep -E -A3 'VGA compatible controller|3D controller|Display controller' || true)"
    if grep -Eq 'Kernel driver in use: (i915|xe|amdgpu|nvidia|nouveau)' <<<"$driver_lines"; then
        log_ok "A supported kernel graphics driver is attached to at least one display controller."
    else
        log_warn "No expected kernel graphics driver was reported for the detected display controller(s). Check 'lspci -k' after reboot."
    fi
}

verify_nks_tree() {
    local -a required=(
        "$TARGET_HOME/.config/hypr/hyprland.lua"
        "$TARGET_HOME/.config/waybar/config.jsonc"
        "$TARGET_HOME/.config/waybar/style.css"
        "$TARGET_HOME/.config/rofi/config.rasi"
        "$TARGET_HOME/.config/swaync/config.json"
        "$TARGET_HOME/.config/swaync/style.css"
        "$TARGET_HOME/.config/wallust/wallust-dark.toml"
        "$TARGET_HOME/.config/wlogout/layout"
        "$USER_BIN_DIR/customize"
        "$USER_BIN_DIR/start-navbar"
        "$USER_BIN_DIR/nks-open-file-manager"
        "$TARGET_HOME/.face.icon"
        "$TARGET_HOME/change-avatar.sh"
    )
    local f
    for f in "${required[@]}"; do [[ -e "$f" ]] || die "Installed NKS file is missing: $f"; done
    command -v hyprland >/dev/null 2>&1 || die "hyprland is missing from PATH."
    command -v sddm >/dev/null 2>&1 || die "sddm is missing from PATH."
    command -v waybar >/dev/null 2>&1 || die "waybar is missing from PATH."
    command -v swaync >/dev/null 2>&1 || die "swaync is missing from PATH."
    command -v rofi >/dev/null 2>&1 || die "rofi is missing from PATH."
    command -v awww >/dev/null 2>&1 || die "awww is missing from PATH."
    command -v mpvpaper >/dev/null 2>&1 || die "mpvpaper is missing from PATH."
    command -v wallust >/dev/null 2>&1 || die "wallust is missing from PATH."
    command -v hyprshot >/dev/null 2>&1 || die "hyprshot is missing from PATH."
    [[ -f /usr/include/nlohmann/json.hpp ]] || die "nlohmann/json.hpp is missing from the system."
    command -v lspci >/dev/null 2>&1 || die "pciutils/lspci is missing from the system."
    command -v nautilus >/dev/null 2>&1 || die "nautilus is missing from the system."
    command -v gnome-text-editor >/dev/null 2>&1 || die "gnome-text-editor is missing from the system."
    command -v nwg-displays >/dev/null 2>&1 || die "nwg-displays is missing from the system."
    command -v nwg-look >/dev/null 2>&1 || die "nwg-look is missing from the system."
    command -v vulkaninfo >/dev/null 2>&1 || die "vulkan-tools/vulkaninfo is missing from the system."
    [[ -x /usr/bin/qt6ct ]] || die "qt6ct is missing from the system."
    log_ok "NKS runtime command, graphics-tool, and native-header verification passed."

    if command -v luac >/dev/null 2>&1; then
        luac -p "$TARGET_HOME/.config/hypr/hyprland.lua"
        log_ok "Lua syntax check passed for hyprland.lua."
    else
        log_warn "luac is unavailable in this build environment; runtime Lua validation will occur when Hyprland starts."
    fi
}

check_display_manager_conflict() {
    local dm=""
    if [[ -L /etc/systemd/system/display-manager.service ]]; then
        dm="$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null || true)"
    fi
    if [[ -n "$dm" && "$dm" != */sddm.service ]]; then
        die "Another display manager is already selected: $dm. Disable/remove that display-manager choice first, then rerun NKS. NKS will not force-replace an existing display manager."
    fi
}

configure_qylock_sddm() {
    check_display_manager_conflict
    local helper="$SCRIPT_DIR/scripts/qylock-sddm.sh"
    [[ -x "$helper" ]] || die "Qylock helper is not executable."
    log_info "Configuring Qylock for SDDM only. No secondary desktop-shell installer will be invoked."
    if ! run "$helper"; then
        log_warn "Qylock setup failed. Continuing with the NKS installation; SDDM remains installed and can be configured later."
    fi
}

post_install_check() {
    log_info "Final checks."
    sudo systemctl is-enabled sddm.service >/dev/null 2>&1 || die "sddm.service is not enabled."
    if [[ -d /usr/share/wayland-sessions ]]; then
        [[ -f /usr/share/wayland-sessions/hyprland.desktop ]] || log_warn "Hyprland Wayland session file was not found yet; verify the installed package if SDDM does not list Hyprland."
    fi

    cat <<MSG

NeKoRoSHELL installation completed for: $TARGET_USER
Config entrypoint: $TARGET_HOME/.config/hypr/hyprland.lua
Backup: ${BACKUP_ARCHIVE:-none}
SDDM: enabled
Qylock: SDDM setup only
GPU profile: $(cat "$TARGET_HOME/.cache/nekoroshell/gpu-profile" 2>/dev/null || echo generic)

Reboot to start through SDDM:
  systemctl reboot

For an existing Hyprland/dotfiles installation, the backup above is the rollback point.
MSG
}

main() {
    parse_args "$@"
    validate_source_tree
    detect_os

    # Resolve user first; if this installer was started as root, re-enter as the
    # detected normal account. That keeps all user-owned files owned by the user.
    find_human_user
    reexec_as_user "$@"
    ensure_runtime_user
    require_user_sudo
    check_existing_frameworks
    check_display_manager_conflict

    # Create the rollback archive before any package installation or user configuration
    # mutation. This keeps the existing desktop state recoverable if a later phase fails.
    create_backup

    log_info "NeKoRoSHELL ${NKS_VERSION} — standalone Arch installer"
    install_official_packages
    ensure_aur_helper
    configure_graphics
    configure_networking
    install_aur_packages
    install_zsh_and_shell
    install_home_files
    atomic_deploy
    generate_hardware_lua
    install_binaries
    finalize_paths_and_permissions
    if (( DRY_RUN )); then
        log_ok "Dry-run completed. No system or user files were modified."
        return 0
    fi
    verify_hyprland_version
    verify_graphics_stack
    verify_display_stack
    verify_nks_tree
    configure_qylock_sddm
    post_install_check
}

main "$@"
