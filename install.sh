#!/usr/bin/env bash
set -e
set -o pipefail

readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
readonly TIMESTAMP=$(date +%Y%m%d_%H%M%S)
readonly CONFIGS=(btop cava fastfetch hypr hypremoji kitty rofi swaync systemd wallpapers wallust waybar wlogout themes)

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

DRY_RUN=0
NO_CONFIRM=0
INSTALL_TYPE=""
USER_BIN_DIR=""
OS_ID=""
AUR_HELPER=""
TARGET_USER=""

cleanup_install_temp() {
    [[ -n "${NKS_PACKAGE_FILE_OVERRIDE:-}" ]] && rm -f -- "$NKS_PACKAGE_FILE_OVERRIDE" 2>/dev/null || true
}
trap cleanup_install_temp EXIT

log_info()    { echo -e "${BLUE}$1${NC}"; }
log_success() { echo -e "  [✔] ${GREEN}$1${NC}"; }
log_warn()    { echo -e "  [!] ${RED}$1${NC}"; }
log_error()   { echo -e "${RED}$1${NC}"; }

execute() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo -e "  ${BLUE}[DRY-RUN]${NC} Would execute: $*"
    else
        "$@"
    fi
}

parse_arguments() {
    for arg in "$@"; do
        if [[ "$arg" == "--no-confirm" || "$arg" == "-y" ]]; then
            NO_CONFIRM=1
        elif [[ "$arg" == "--dry-run" || "$arg" == "-d" ]]; then
            DRY_RUN=1
            echo -e "${BLUE}============ DRY-RUN MODE ============${NC}"
            echo -e "${GREEN}No files will be modified or copied.${NC}"
            echo -e "${BLUE}======================================${NC}\n"
        fi
    done
}

detect_runtime_user() {
    TARGET_USER="${SUDO_USER:-${USER:-}}"
    if [[ -z "$TARGET_USER" ]] || ! id "$TARGET_USER" >/dev/null 2>&1 || [[ "$TARGET_USER" == "root" ]]; then
        TARGET_USER="$(logname 2>/dev/null || true)"
    fi
    if [[ -z "$TARGET_USER" ]] || ! id "$TARGET_USER" >/dev/null 2>&1 || [[ "$TARGET_USER" == "root" ]]; then
        log_error "No non-root login user could be identified. Run archinstall first, create a normal user, then run this installer from that user's session."
        exit 1
    fi
    if [[ "$HOME" == "/root" ]]; then
        HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
        export HOME
    fi
    log_success "Target user: $TARGET_USER (home: $HOME)"
}

detect_bin_directory() {
    log_info "Detecting active user bin directory..."
    local base_bin_dir
    if [[ -d "$HOME/.local/bin" ]]; then
        base_bin_dir="$HOME/.local/bin"
    elif [[ -d "$HOME/bin" ]]; then
        base_bin_dir="$HOME/bin"
    else
        base_bin_dir="$HOME/.local/bin"
    fi

    USER_BIN_DIR="$base_bin_dir/nekoroshell"
    echo -e "${GREEN}Using $USER_BIN_DIR as the target bin directory.${NC}\n"
}

prompt_install_type() {
    if [[ "$NO_CONFIRM" -eq 1 ]]; then
        INSTALL_TYPE="compilation"
        cache_sudo
        log_success "--no-confirm selected: Compilation installation."
        echo ""
        return 0
    fi
    log_info "Please choose your installation type:"
    echo -e "  ${GREEN}Minimal${NC}     - Backup existing configs, deploy dotfiles, and replace hardcoded directories. No dependencies."
    echo -e "  ${GREEN}Compilation${NC} - Backup existing configs, deploy dotfiles, replace hardcoded directories, and install every dependency.\n"

    while true; do
        echo -ne "${BLUE}Type 'Minimal' or 'Compilation' to proceed (or 'exit' to abort): ${NC}"
        read -r choice
        choice="${choice,,}"

        if [[ "$choice" == "minimal" ]]; then
            INSTALL_TYPE="minimal"
            log_success "Minimal installation selected."
            break
        elif [[ "$choice" == "compilation" ]]; then
            INSTALL_TYPE="compilation"
            log_success "Compilation installation selected."
            cache_sudo
            break
        elif [[ "$choice" == "exit" ]]; then
            log_error "Installation aborted."
            exit 0
        else
            log_error "Invalid input. Please type 'Minimal' or 'Compilation'."
        fi
    done
    echo ""
}

cache_sudo() {
    log_info "Caching sudo credentials for dependency installation..."
    sudo -v
    exec 9> >(
        while true; do
            read -r -t 60
            status=$?
            if [[ $status -gt 128 ]]; then
                sudo -n true 2>/dev/null
            else
                break
            fi
        done
    )
}

detect_os() {
    log_info "Detecting operating system details..."
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS_ID=$ID
        if [[ "$OS_ID" == "linuxmint" ]] || [[ "$OS_ID" == "pop" ]]; then
            OS_ID="ubuntu"
        fi
    else
        log_error "Cannot detect operating system. /etc/os-release not found."
        exit 1
    fi
    log_success "Detected OS: $OS_ID"
}

bootstrap_base_dependencies() {
    log_info "Bootstrapping base dependencies..."
    
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
    fi

    if [[ "$OS_ID" == "arch" || "$ID_LIKE" == *"arch"* ]]; then
        execute sudo pacman -Syu --needed --noconfirm base-devel git cargo go flatpak
        if ! command -v yay &> /dev/null; then
            if [[ "$DRY_RUN" -eq 1 ]]; then
                echo -e "  ${BLUE}[DRY-RUN]${NC} Would clone and install yay from AUR"
            else
                rm -rf /tmp/yay
                sudo -u "$TARGET_USER" git clone https://aur.archlinux.org/yay.git /tmp/yay
                cd /tmp/yay
                sudo -u "$TARGET_USER" makepkg -si --noconfirm
                cd "$SCRIPT_DIR"
            fi
        fi
    elif [[ "$OS_ID" == "fedora" ]]; then
        execute sudo dnf install -y @development-tools git cargo golang flatpak
    elif [[ "$OS_ID" == "debian" || "$OS_ID" == "ubuntu" ]]; then
        execute sudo apt update
        execute sudo apt install -y build-essential git cargo golang flatpak
    else
        log_warn "Unsupported OS for automatic bootstrap. Please install prerequisites manually."
    fi
}

enable_multilib_if_needed() {
    [[ -f /etc/pacman.conf ]] || return 0
    # lib32 graphics/runtime packages require the Multilib repository.
    local pkg_file="${NKS_PACKAGE_FILE_OVERRIDE:-packages/pkglist-arch.txt}"
    if ! grep -Eq '^[[:space:]]*lib32-' "$pkg_file"; then
        return 0
    fi
    if grep -Eq '^\[multilib\]' /etc/pacman.conf; then
        return 0
    fi
    log_info "Enabling Arch multilib repository for 32-bit graphics/runtime dependencies..."
    sudo cp -a /etc/pacman.conf "/etc/pacman.conf.nks-backup-$TIMESTAMP"
    sudo sed -i -e '/^#[[]multilib[]]$/,+1 s/^#//' /etc/pacman.conf
    if ! grep -Eq '^\[multilib\]' /etc/pacman.conf; then
        printf '
[multilib]
Include = /etc/pacman.d/mirrorlist
' | sudo tee -a /etc/pacman.conf >/dev/null
    fi
    sudo pacman -Sy --noconfirm
}

install_arch_packages() {
    local pkg_file="${NKS_PACKAGE_FILE_OVERRIDE:-packages/pkglist-arch.txt}"
    local -a requested official aur missing
    mapfile -t requested < <(sed 's/[[:space:]"]//g' "$pkg_file" | grep -vE '^$|^#')
    official=(); aur=(); missing=()

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log_info "[DRY-RUN] Would resolve and install packages from $pkg_file using pacman/AUR helper."
        return 0
    fi

    enable_multilib_if_needed
    log_info "Resolving Arch packages against the current repositories..."
    local pkg
    for pkg in "${requested[@]}"; do
        if pacman -Si "$pkg" >/dev/null 2>&1; then
            official+=("$pkg")
        elif "$AUR_HELPER" -Si "$pkg" >/dev/null 2>&1; then
            aur+=("$pkg")
        else
            missing+=("$pkg")
        fi
    done

    if ((${#official[@]})); then
        log_info "Installing ${#official[@]} official Arch packages."
        sudo pacman -S --needed --noconfirm "${official[@]}"
    fi
    if ((${#aur[@]})); then
        log_info "Installing ${#aur[@]} AUR packages through $AUR_HELPER."
        "$AUR_HELPER" -S --needed --noconfirm "${aur[@]}"
    fi
    if ((${#missing[@]})); then
        log_warn "Unavailable package names: ${missing[*]}"
    fi
}

install_bulk_packages() {
    local target_os="$1"
    shift
    if [[ "$target_os" == "arch" ]]; then
        install_arch_packages
        return 0
    fi
    local pkg_file="packages/pkglist-${target_os}.txt"
    local install_cmd=("$@")
    if [[ -f "$pkg_file" ]]; then
        mapfile -t pkg_array < <(sed 's/[[:space:]"]//g' "$pkg_file" | grep -vE '^$|^#')
        if ((${#pkg_array[@]})); then
            log_info "Installing $target_os packages in bulk..."
            "${install_cmd[@]}" "${pkg_array[@]}" || log_warn "Bulk install failed. Check output above."
        fi
    else
        log_warn "$pkg_file not found!"
    fi
}

install_gpu_drivers() {
    log_info "Detecting graphics hardware and installing matching userspace/drivers..."
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log_info "[DRY-RUN] Would install the graphics stack selected by GPU detection."
        return 0
    fi
    local info="$(lspci -nn 2>/dev/null | grep -Ei 'VGA compatible controller|3D controller|Display controller' || true)"
    if grep -qi 'NVIDIA' <<<"$info"; then
        if grep -Eqi '(GTX 10[0-9]{2}|GTX 9[0-9]{2}|GTX 8[0-9]{2}|GTX 7[0-9]{2}|Quadro|Tesla)' <<<"$info"; then
            log_info "NVIDIA pre-Turing/legacy GPU detected; using the current Arch legacy NVIDIA package family."
            "$AUR_HELPER" -S --needed --noconfirm nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils || log_warn "Legacy NVIDIA package install failed; Nouveau will remain available."
        else
            log_info "NVIDIA Turing-or-newer GPU detected; using nvidia-open."
            "$AUR_HELPER" -S --needed --noconfirm nvidia-open nvidia-utils lib32-nvidia-utils nvidia-prime || log_warn "NVIDIA open-driver install failed; verify the GPU/driver pairing manually."
        fi
    elif grep -qi 'AMD\|ATI' <<<"$info"; then
        "$AUR_HELPER" -S --needed --noconfirm mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon libva-mesa-driver mesa-vdpau || log_warn "Some AMD graphics packages failed to install."
    elif grep -qi 'Intel' <<<"$info"; then
        "$AUR_HELPER" -S --needed --noconfirm mesa lib32-mesa vulkan-intel lib32-vulkan-intel intel-media-driver || log_warn "Some Intel graphics packages failed to install."
    else
        log_warn "No supported GPU vendor was detected; installing generic Mesa/Vulkan userspace."
        "$AUR_HELPER" -S --needed --noconfirm mesa lib32-mesa vulkan-icd-loader lib32-vulkan-icd-loader || true
    fi
}

install_system_dependencies() {
    log_info "Installing system dependencies..."
    
    case "$OS_ID" in
        arch|endeavouros|manjaro)
            if command -v paru &> /dev/null; then AUR_HELPER="paru"
            elif command -v yay &> /dev/null; then AUR_HELPER="yay"
            else log_error "Error: yay or paru is required for Arch-based systems."; exit 1; fi
            local filtered_pkg_file="$XDG_CACHE_HOME/nekoroshell-pkglist-arch.txt"
            mkdir -p "$XDG_CACHE_HOME"
            cp -f "$SCRIPT_DIR/packages/pkglist-arch.txt" "$filtered_pkg_file"
            if pacman -Q jack2 >/dev/null 2>&1; then
                sed -i '/^pipewire-jack$/d' "$filtered_pkg_file"
                log_warn "jack2 is already installed; pipewire-jack will be skipped for this install."
            fi
            if pacman -Q pulseaudio >/dev/null 2>&1; then
                sed -i '/^pipewire-pulse$/d' "$filtered_pkg_file"
                log_warn "pulseaudio is already installed; pipewire-pulse will be skipped for this install."
            fi
            NKS_PACKAGE_FILE_OVERRIDE="$filtered_pkg_file" install_arch_packages
            rm -f "$filtered_pkg_file"
            install_gpu_drivers
            ;;
        fedora)
            install_bulk_packages "fedora" sudo dnf install -y
            ;;
        ubuntu|debian)
            log_error "WARNING: Debian/Ubuntu do not provide Hyprland or its ecosystem natively."
            log_error "Ensure you have installed them via a 3rd party PPA/script first."
            sleep 3
            execute sudo apt-get update
            install_bulk_packages "debian" sudo apt-get install -y
            ;;
        gentoo)
            install_bulk_packages "gentoo" sudo emerge -av --noreplace
            ;;
        *)
            log_error "Unsupported OS: $OS_ID. Please install dependencies manually."
            echo -ne "Do you wish to continue with config deployment anyway? (y/n): "
            read -r continue_ans
            if [[ ! "$continue_ans" =~ ^[Yy]$ ]]; then exit 1; fi
            ;;
    esac

    install_cargo_packages
    install_go_packages
    install_flatpaks
}

install_cargo_packages() {
    log_info "Checking for packages that require Cargo (Rust)..."
    if command -v cargo &> /dev/null; then
        export PATH="$HOME/.cargo/bin:$PATH"
        if ! command -v wallust &> /dev/null; then
            log_info "Installing wallust via Cargo as a package-manager fallback..."
            execute cargo install wallust || log_warn "Failed to install wallust."
        else
            log_success "wallust is already installed."
        fi
        if ! command -v awww &> /dev/null; then
            log_warn "awww is not installed after the Arch package stage; wallpaper support will be unavailable until awww is installed."
        else
            log_success "awww is already installed."
        fi
    else
        log_warn "Cargo is not installed. Skipping the wallust fallback; awww is provided by the Arch package stage."
    fi
}

install_go_packages() {
    log_info "Checking for packages that require Go..."
    if command -v go &> /dev/null; then
        GOPATH=$(go env GOPATH 2>/dev/null || echo "$HOME/go")
        export PATH="$GOPATH/bin:$PATH"
        if ! command -v cliphist &> /dev/null; then
            log_info "Installing cliphist via Go..."
            execute go install go.senan.xyz/cliphist@latest || log_warn "Failed to install cliphist."
        else
            log_success "cliphist is already installed."
        fi
    else
        log_warn "Go is not installed. Skipping cliphist."
    fi
}

install_flatpaks() {
    if command -v flatpak &> /dev/null; then
        if [[ -f "flatpak.txt" ]]; then
            log_info "Installing flatpak packages..."
            execute sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
            if [[ "$DRY_RUN" -eq 1 ]]; then
                echo -e "  ${BLUE}[DRY-RUN]${NC} Would install flatpaks listed in flatpak.txt"
            else
                grep -vE '^\s*#|^\s*$' flatpak.txt | xargs -r sudo flatpak install -y flathub || log_warn "Some flatpaks failed to install."
            fi
        else
            log_warn "flatpak.txt not found!"
        fi
    fi
}

backup_existing_configs() {
    log_info "Creating backup of existing configs..."
    execute mkdir -p "$XDG_CONFIG_HOME"
    
    local backup_archive="$HOME/nekoroshell_backup_$TIMESTAMP.tar.gz"
    local backup_items=()

    for conf in "${CONFIGS[@]}"; do
        if [[ -e "$XDG_CONFIG_HOME/$conf" ]]; then
            backup_items+=("$conf")
        fi
    done

    if [[ ${#backup_items[@]} -gt 0 ]]; then
        execute tar -czf "$backup_archive" -C "$XDG_CONFIG_HOME" "${backup_items[@]}"
        log_success "Created backup archive at: $backup_archive"
    else
        log_success "No existing configs found. Skipping backup."
    fi
}

deploy_configs() {
    log_info "Deploying NeKoRoSHELL configuration files..."
    for conf in "${CONFIGS[@]}"; do
        if [[ -d ".config/$conf" || -f ".config/$conf" ]]; then
            execute rm -rf "$XDG_CONFIG_HOME/$conf"
            execute cp -a ".config/$conf" "$XDG_CONFIG_HOME/"
            log_success "Copied $conf"
        else
            log_warn ".config/$conf missing in source directory."
        fi
    done
}

initialize_sandbox() {
    log_info "Initializing user configuration sandbox..."
    
    local user_conf_dir="$XDG_CONFIG_HOME/hypr/user/configs"
    local user_script_dir="$XDG_CONFIG_HOME/hypr/user/scripts"
    local user_hooks_dir="$XDG_CONFIG_HOME/hypr/user/hooks"
    local template_dir="$XDG_CONFIG_HOME/hypr/user/templates"

    execute mkdir -p "$user_conf_dir" "$user_script_dir" "$user_hooks_dir"

    if [[ -d "$template_dir" ]]; then
        for file in "$template_dir"/*.conf; do
            [ -e "$file" ] || continue 
            local filename=$(basename "$file")
            if [ ! -f "$user_conf_dir/$filename" ]; then
                execute cp "$file" "$user_conf_dir/$filename"
                echo -e "  Initialized user config: $filename"
            fi
        done
    fi

    if [ ! -f "$user_script_dir/autostart.sh" ]; then
        if [[ "$DRY_RUN" -eq 1 ]]; then
            echo -e "  ${BLUE}[DRY-RUN]${NC} Would create initialized user autostart.sh"
        else
            echo -e "#!/bin/bash\n# Add your personal startup commands here" > "$user_script_dir/autostart.sh"
            chmod +x "$user_script_dir/autostart.sh"
            echo -e "  Initialized user autostart script."
        fi
    fi

    [[ ! -f "$user_hooks_dir/post-install.sh" ]] && echo -e "#!/usr/bin/env bash\n# Runs once after NeKoRoSHELL finishes a fresh install." > "$user_hooks_dir/post-install.sh"
    [[ ! -f "$user_hooks_dir/post-update.sh" ]] && echo -e "#!/usr/bin/env bash\n# Runs every time 'nekoroshell update' completes successfully." > "$user_hooks_dir/post-update.sh"
    [[ ! -f "$user_hooks_dir/on-theme-change.sh" ]] && echo -e "#!/usr/bin/env bash\n# Runs when a new theme is applied. \$1 is the theme name." > "$user_hooks_dir/on-theme-change.sh"
    
    execute chmod +x "$user_hooks_dir"/*.sh 2>/dev/null || true
}

configure_hardware() {
    log_info "Analyzing hardware..."
    local hw_conf="$XDG_CONFIG_HOME/hypr/user/configs/hardware.conf"
    local gpu="$(lspci -nn 2>/dev/null | grep -Ei 'VGA compatible controller|3D controller|Display controller' | head -1 || true)"
    mkdir -p "$(dirname "$hw_conf")"
    {
        echo '# NeKoRoSHELL Auto-Generated Hardware Profile'
        if ls /sys/class/power_supply/BAT* >/dev/null 2>&1; then
            cat <<'EOF'
# Laptop-specific optimizations
gesture = 3, horizontal, workspace
gesture = 3, down, close
gesture = 4, pinch, fullscreen
EOF
        fi
        if grep -qi 'NVIDIA' <<<"$gpu"; then
            cat <<'EOF'
# NVIDIA runtime environment
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = LIBVA_DRIVER_NAME,nvidia
env = NVD_BACKEND,direct
EOF
        fi
    } > "$hw_conf"
    log_success "Generated hardware profile."
}

configure_monitors() {
    log_info "Detecting connected monitors..."
    local monitor_conf="$XDG_CONFIG_HOME/hypr/user/configs/monitors.conf"
    mkdir -p "$(dirname "$monitor_conf")"
    mapfile -t outputs < <(for f in /sys/class/drm/card*-*/status; do [[ -f "$f" && "$(cat "$f")" == connected ]] || continue; b="$(basename "$(dirname "$f")")"; printf '%s\n' "${b#*-}"; done | awk 'NF && !seen[$0]++')
    {
      echo '###################'
      echo '### MONITORS ######'
      echo '###################'
      if ((${#outputs[@]})); then
        for out in "${outputs[@]}"; do printf 'monitor = %s, preferred, auto, 1\n' "$out"; done
        log_success "Configured ${#outputs[@]} detected display output(s)."
      else
        echo 'monitor = , preferred, auto, 1'
        log_warn "No connector reported connected during installation; generic monitor fallback retained."
      fi
    } > "$monitor_conf"
}

patch_hardcoded_paths() {
    local search="/home/nekorosys"
    local replace="$HOME"
    
    local replace_escaped
    replace_escaped=$(echo "$replace" | sed 's/|/\\|/g; s/\\/\\\\/g')
    
    log_info "Replacing hardcoded paths ($search -> $replace)..."
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo -e "  ${BLUE}[DRY-RUN]${NC} Would replace hardcoded paths across config files."
        return
    fi

    local target_dirs=()
    for conf in "${CONFIGS[@]}"; do
        if [[ -d "$XDG_CONFIG_HOME/$conf" ]]; then
            target_dirs+=("$XDG_CONFIG_HOME/$conf")
        fi
    done

    if [[ ${#target_dirs[@]} -gt 0 ]]; then
        find "${target_dirs[@]}" -type f \( \
            -name "*.config" -o -name "*.css" -o -name "*.rasi" \
            -o -name "*.conf" -o -name "*.sh" -o -name "*.json*" \
            -o -name "*.lua" -o -name "*.py" -o -name "*.yaml" \
        \) -exec grep -l "$search" {} + 2>/dev/null | while read -r file; do
            sed -i "s|$search|$replace_escaped|g" "$file"
        done
        log_success "Paths patched successfully."
    fi
}

inject_shell_rc() {
    inject_func() {
        local shell_rc="$1"
        local source_rc="$2"
        
        local go_bin_path
        if command -v go &> /dev/null; then
            go_bin_path="$(go env GOPATH 2>/dev/null || echo "$HOME/go")/bin"
        else
            go_bin_path="$HOME/go/bin"
        fi
        
        local export_bin_dir="${USER_BIN_DIR/$HOME/\$HOME}"
        
        if [[ ! -f "$shell_rc" ]]; then
            execute touch "$shell_rc"
        fi
        if [[ -f "$shell_rc" ]]; then
            if [[ "$DRY_RUN" -eq 1 ]]; then
                echo -e "  ${BLUE}[DRY-RUN]${NC} Would inject NeKoRoSHELL path/config blocks into $shell_rc"
            else
                sed -i '/# --- NeKoRoSHELL START ---/,/# --- NeKoRoSHELL END ---/d' "$shell_rc"
                echo -e "\n# --- NeKoRoSHELL START ---" >> "$shell_rc"
                [[ -f "$source_rc" ]] && cat "$source_rc" >> "$shell_rc"
                echo "export PATH=\"$export_bin_dir:\$HOME/.cargo/bin:$go_bin_path:\$PATH\"" >> "$shell_rc"
                echo -e "# --- NeKoRoSHELL END ---" >> "$shell_rc"
                log_success "Updated $shell_rc"
            fi
        fi
    }

    inject_func "$HOME/.bashrc" "home/.bashrc"
    inject_func "$HOME/.zshrc" "home/.zshrc"

    [[ -f home/.p10k.zsh ]] && execute cp home/.p10k.zsh "$HOME/"
    [[ -f home/.face.icon ]] && execute cp home/.face.icon "$HOME/"
    [[ -f home/change-avatar.sh ]] && execute cp home/change-avatar.sh "$HOME/"

    if [[ -d bin ]]; then
        log_info "Copying scripts to $USER_BIN_DIR..."
        execute mkdir -p "$USER_BIN_DIR"
        execute cp -r bin/* "$USER_BIN_DIR/" 2>/dev/null || true
    fi
}

compile_daemons_and_tools() {
    if ! command -v hyprshot &> /dev/null; then
        log_info "Downloading hyprshot..."
        execute mkdir -p "$USER_BIN_DIR"
        execute curl -sLo "$USER_BIN_DIR/hyprshot" https://raw.githubusercontent.com/Gustash/Hyprshot/main/hyprshot || true
        execute chmod +x "$USER_BIN_DIR/hyprshot" || true
    fi

    if [[ ! -d "$HOME/powerlevel10k" ]]; then
        log_info "Cloning Powerlevel10k theme..."
        execute git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$HOME/powerlevel10k" || true
    fi

    if ! command -v g++ &> /dev/null; then
        log_error "g++ is not installed. Please install build tools to compile C++ daemons."
    elif ! command -v pkg-config &> /dev/null; then
        log_error "pkg-config is not installed. Cannot verify C++ header dependencies."
    else
        log_info "Checking C++ build dependencies..."
        local required_libs="wayland-client" 
        
        if ! pkg-config --exists $required_libs; then
            log_error "Missing required C++ development headers: $required_libs"
            log_error "Please install the corresponding -dev / -devel packages. Compilation aborted."
        else
            log_info "Compiling C++ Daemons via Make..."
            execute mkdir -p "$USER_BIN_DIR"
            
            if execute make clean all; then
                log_success "Successfully compiled all C++ daemons."
                execute cp build/* "$USER_BIN_DIR/" || log_warn "Failed to copy binaries to $USER_BIN_DIR"
            else
                log_error "Compilation failed. Check the output above."
            fi
        fi
    fi
}

configure_qylock_sddm() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log_info "[DRY-RUN] Would configure Qylock for SDDM only."
        return 0
    fi
    if ! command -v sddm >/dev/null 2>&1; then
        log_warn "SDDM is not installed; skipping Qylock integration."
        return 0
    fi
    if [[ ! -x "$SCRIPT_DIR/scripts/qylock-sddm.sh" ]]; then
        log_warn "Qylock helper missing; skipping."
        return 0
    fi
    log_info "Configuring Qylock for SDDM only (no Quickshell integration)."
    "$SCRIPT_DIR/scripts/qylock-sddm.sh" || log_warn "Qylock setup failed; continuing with the rest of NKS."
}

finalize_permissions_and_verify() {
    log_info "Setting script permissions..."
    execute find "$XDG_CONFIG_HOME/" -type f -name "*.sh" -exec chmod +x {} + 2>/dev/null || true

    for bin_dir in "$HOME/.local/bin/nekoroshell" "$HOME/bin/nekoroshell"; do
        if [[ -d "$bin_dir" ]]; then
            execute find "$bin_dir/" -type f -exec chmod +x {} + 2>/dev/null || true
        fi
    done

    log_info "Performing final system check..."
    local core_cmds=("hyprland" "btop" "cava" "fastfetch" "hypremoji" "waybar" "swaync" "rofi" "kitty" "wallust" "awww" "nautilus" "gnome-text-editor" "gnome-calculator" "nwg-displays" "nwg-look" "sddm")
    local missing=0

    for cmd in "${core_cmds[@]}"; do
        if command -v "$cmd" &> /dev/null; then
            echo -e "  [${GREEN}OK${NC}] $cmd is installed."
        else
            echo -e "  [${RED}!!${NC}] $cmd is missing from PATH."
            missing=$((missing + 1))
        fi
    done

    if [[ "$missing" -eq 0 ]]; then
        echo -e "\n${GREEN}Everything looks good! NeKoRoSHELL is ready.${NC}"
    else
        echo -e "\n${RED}Warning: $missing core component(s) were not found.${NC}"
        echo -e "If you chose 'Minimal', this is expected. Otherwise, check the logs above."
    fi

    if [[ -x "$HOME/.config/hypr/user/hooks/post-install.sh" ]]; then
        log_info "Executing user post-install hook..."
        "$HOME/.config/hypr/user/hooks/post-install.sh" || log_warn "post-install hook failed."
    fi
    
    echo -e "\n${GREEN}Installation complete! Please restart your session to apply all changes.${NC}"
}

main() {
    cd "$SCRIPT_DIR" || { log_error "Failed to navigate to script directory."; exit 1; }
    
    parse_arguments "$@"
    detect_runtime_user

    echo -e "# ======================================================= #"
    echo -e "#            NeKoRoSHELL Installation Wizard              #"
    echo -e "# ======================================================= #\n"

    detect_bin_directory
    prompt_install_type

    log_info "Starting $INSTALL_TYPE installation..."

    if [[ "$INSTALL_TYPE" == "compilation" ]]; then
        detect_os
        bootstrap_base_dependencies
        install_system_dependencies
    fi

    backup_existing_configs
    deploy_configs
    initialize_sandbox
    configure_hardware
    configure_monitors
    patch_hardcoded_paths
    inject_shell_rc
    configure_qylock_sddm

    if [[ "$INSTALL_TYPE" == "compilation" ]]; then
        compile_daemons_and_tools
    fi

    finalize_permissions_and_verify
}

main "$@"
