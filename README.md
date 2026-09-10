# NeKoRoSHELL 1.6 — Standalone Hyprland Dotfiles

NeKoRoSHELL is a modular Hyprland desktop environment built around Waybar, SwayNC, Rofi, Hyprland, wallpaper tools, native helper programs, and a selectable collection of skins and themes.

This repository is the standalone Arch Linux version. It installs the desktop components, deploys a native Hyprland Lua configuration, configures SDDM with Qylock, builds the native NKS helpers, and detects the installed graphics hardware before selecting the appropriate driver path.

The repository is intended to be used as one coherent dotfiles project: `install.sh` is the entry point, `.config/` contains the desktop configuration, `bin/` contains user-facing commands, `scripts/` contains integration helpers, and `packages/` contains the Arch dependency manifests.

## What is included

The deployed configuration is centered on:

- Hyprland 0.55+ using native Lua configuration
- Waybar with static, dynamic, and hover navbar modes
- SwayNC notifications and control centre
- Rofi launcher, command runner, game launcher, and customization menus
- Hyprlock with multiple lockscreen layouts
- Hyprland-native Lua window skins
- Wlogout power menu
- Nautilus as the file manager
- GNOME Text Editor and GNOME Calculator
- `nwg-displays` for monitor configuration
- `nwg-look` for GTK appearance configuration
- `awww` for image wallpapers
- `mpvpaper` for video wallpapers
- Wallust-derived dynamic colours
- Oh My Posh with a compact Zen-style Zsh prompt
- bundled user profile icon at `~/.face.icon`
- Qylock for SDDM
- Zsh autosuggestions and syntax highlighting
- Small C++ helper programs for the navbar and related desktop behaviour

The active Hyprland entrypoint is:

```text
~/.config/hypr/hyprland.lua
```

Personal Hyprland overrides can be placed in:

```text
~/.config/hypr/custom.lua
```

The installer generates a machine-specific graphics and display file at:

```text
~/.config/hypr/hardware.lua
```

It records supported GPU environment settings and connected DRM outputs detected during installation. Connected outputs are configured to use their preferred mode at scale 1; the main Lua configuration also contains a generic preferred-mode fallback for displays connected later. Use `nwg-displays` for persistent multi-monitor arrangements.

---

# Installation

## Requirements

Start with a working Arch Linux installation and a normal desktop user with sudo access. A minimal installation created with `archinstall` is suitable. The installer does not partition disks, format filesystems, or install a bootloader.

The installer expects to run on the installed Arch system, not from a temporary live environment or chroot that does not represent the final desktop installation.

## Fresh installation

From the repository root:

```bash
chmod +x install.sh
./install.sh
```

For package and AUR transactions without confirmation prompts:

```bash
./install.sh --no-confirm
```

For a preview of the actions:

```bash
./install.sh --dry-run
```

`--no-confirm` only removes package/AUR transaction confirmations. It does not approve replacement of an existing desktop configuration, and the Qylock setup helper may still present its own theme/setup choices.

## Existing Hyprland dotfiles

The installer checks for an existing Hyprland/dotfiles setup and refuses to take it over silently. Use:

```bash
./install.sh --replace-existing
```

A backup is created before replacement under:

```text
~/NeKoRoSHELL-backups/
```

For a non-interactive replacement:

```bash
./install.sh --replace-existing --no-confirm
```

On systems with several normal users, choose the target account explicitly:

```bash
./install.sh --user USER --no-confirm
```

Running the installer as root is supported. The script finds the normal `/home/...` account and re-enters the installer as that user so user-owned files are not installed as root. If no suitable normal account exists, the installer stops rather than creating one implicitly.

## After installation

Reboot to enter through SDDM:

```bash
systemctl reboot
```

Qylock is configured for SDDM during installation. NKS does not require a second login-screen framework.

---

# Packages

The two Arch manifests are the package source of truth:

```text
packages/pkglist-arch.txt
packages/aurpkglist-arch.txt
```

The official repository manifest contains the compositor, desktop applications, Wayland libraries, graphics stack, PipeWire, NetworkManager, Bluetooth, fonts, Qt/GStreamer runtime pieces, and build dependencies. The AUR manifest contains the packages that are not supplied by the official repositories and are directly used by the NKS configuration.

The repository does not pin a historical Hyprland release. The installer installs the current Arch package available at installation time and then verifies that the installed Hyprland version is at least 0.55. Current Arch documentation uses Lua for Hyprland configuration starting with 0.55.

---

# AUR helper behaviour

The installer looks for an existing AUR helper in this order:

```text
paru
  ↓
yay
  ↓
build yay automatically
```

When neither helper exists, `yay` is built as the normal desktop user. AUR build operations are not performed as root.

---

# Hardware and graphics support

NKS detects Intel, AMD, and NVIDIA display controllers from PCI information and records the result in:

```text
~/.cache/nekoroshell/detected-gpus.txt
~/.cache/nekoroshell/gpu-profile
```

The diagnostic command is:

```bash
nks-gpu-info
```

## Intel

Intel graphics use the Mesa stack with the official `vulkan-intel` and Intel VA-API packages from the Arch repositories. The generated Hyprland hardware configuration does not add NVIDIA-specific environment variables.

## AMD

AMD graphics use Mesa/RADV with the official `vulkan-radeon` and Mesa VA-API packages. The generated Hyprland hardware configuration does not add NVIDIA-specific environment variables.

## NVIDIA

The driver family is selected by GPU generation:

NKS supports the NVIDIA generations for which the current Arch packaging has a viable driver path, but it does **not** guarantee that every NVIDIA GPU can run Hyprland reliably. Very old or unsupported generations may fall back to Nouveau, and Hyprland itself notes that NVIDIA can require additional setup.

| NVIDIA generation | NKS path | Status |
|---|---|---|
| Turing (16xx/20xx), Ampere, Ada, Blackwell and newer supported generations | `nvidia-open` / `nvidia-open-dkms` | Supported |
| Maxwell, Pascal, Volta | `nvidia-580xx-dkms` from the AUR | Supported legacy path |
| Kepler | `nvidia-470xx-dkms` | Not automatically selected by NKS |
| Fermi | `nvidia-390xx-dkms` | Not automatically selected by NKS |
| Tesla | `nvidia-340xx-dkms` | Not automatically selected by NKS |
| Curie and older | no current Arch NVIDIA package | Unsupported |

Concrete examples:

- **GeForce GTX 1660 Ti** is Turing. NKS selects `nvidia-open` on a standard `linux` installation, or `nvidia-open-dkms` when a DKMS path is required.
- **GeForce GTX 1060 6 GB** is Pascal. NKS selects the `nvidia-580xx-dkms` AUR path.

The installer also checks for the running kernel's module build directory before a DKMS-based installation and adds matching headers for the official Arch kernel packages it detects.

After installation, the generated NVIDIA Hyprland environment contains the variables documented by the current Hyprland NVIDIA guidance:

```lua
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
```

NVIDIA hybrid graphics are hardware-specific. NKS does not blindly force a dedicated GPU as the primary renderer. When a system needs an explicit multi-GPU choice, Hyprland's `AQ_DRM_DEVICES` mechanism can be configured manually using stable DRM device paths appropriate to that machine.

References:

- Arch NVIDIA documentation: https://wiki.archlinux.org/title/NVIDIA
- Hyprland NVIDIA documentation: https://wiki.hypr.land/nvidia/
- Hyprland multi-GPU documentation: https://wiki.hypr.land/configuring/extra/multi-gpu/

---

# Keybindings

The main bindings are defined in `.config/hypr/hyprland.lua`. For the exact active binding set, run:

```bash
show-keybinds
```

## Applications

| Key | Action |
|---|---|
| `SUPER + RETURN` | Terminal |
| `SUPER + E` | File manager |
| `SUPER + CTRL + RETURN` | Application launcher |
| `SUPER + ALT + M` | Display configuration |
| `SUPER + ALT + N` | GNOME Text Editor |
| `SUPER + ALT + C` | Command launcher |
| `SUPER + SHIFT + C` | Game launcher |

## Windows

| Key | Action |
|---|---|
| `SUPER + Q` | Close active window |
| `SUPER + SHIFT + Q` | Kill active window/process |
| `SUPER + F` | Toggle fullscreen |
| `SUPER + M` | Toggle maximized mode |
| `SUPER + T` | Toggle floating |
| `SUPER + ALT + T` | Toggle floating and pinned |
| `SUPER + J` | Move focus down (Vim-style) |
| `SUPER + SHIFT + J` | Toggle split |
| `SUPER + P` | Toggle pseudo |

## Navigation

| Key | Action |
|---|---|
| `SUPER + Arrow keys` | Move focus |
| `SUPER + H/J/K/L` | Vim-style focus navigation |
| `SUPER + mouse left` | Move window |
| `SUPER + mouse right` | Resize window |
| `SUPER + mouse wheel` | Cycle workspaces |
| `SUPER + ALT + Arrow keys` | Swap windows |
| `SUPER + SHIFT + Arrow keys` | Resize the active window |

## Workspaces and desktop controls

| Key | Action |
|---|---|
| `SUPER + 1..0` | Focus workspace 1..10 |
| `SUPER + SHIFT + 1..0` | Move active window to workspace 1..10 |
| `SUPER + CTRL + R` | Reload Hyprland |
| `SUPER + PRINT` | Screenshot |
| `SUPER + ALT + F` | Full-screen screenshot |
| `SUPER + ALT + S` | Area screenshot |
| `SUPER + CTRL + K` | Show keybindings |
| `SUPER + V` | Clipboard history |
| `SUPER + CTRL + P` | Power menu |
| `SUPER + CTRL + L` | Lock screen |
| `SUPER + SHIFT + W` | Random wallpaper |
| `SUPER + CTRL + W` | Wallpaper selector |
| `SUPER + ALT + G` | Toggle game mode |
| `SUPER + SHIFT + H` | Toggle Hyprsunset |
| `SUPER + SHIFT + B` | Change navbar mode |
| `SUPER + CTRL + B` | Toggle navbar |
| `SUPER + W` | Open customization |
| `SUPER + S` | Toggle scratchpad |
| `SUPER + SHIFT + S` | Move window to scratchpad |

## Media and brightness

The standard XF86 multimedia keys are bound for volume, microphone mute, brightness, and media playback.

---

# Customization and themes

The main customization command is:

```bash
customize
```

`SUPER + W` opens the same selector from Hyprland. It exposes the shipped navbar, launcher, lockscreen, control-centre, power, window, and theme choices.

The customization implementation discovers the available files from the repository rather than requiring a separate hard-coded list. Hyprland window skins are native Lua files under:

```text
.config/hypr/nks-window-skins/
```

The active window skin is recorded in:

```text
~/.cache/nekoroshell/window_skin
```

Detailed skin/theme development notes are in `THEMING.md`.

## Makima themes

The repository includes `makima`, `makima-dark`, and `makima-light`. `makima` remains a compatibility alias for the dark variant. Both variants use the bundled video wallpaper:

```text
.config/wallpapers/makima.mp4
```

`makima-dark` uses a near-black red palette with light text. `makima-light` uses a pale warm background with dark text and restrained red accents. In both variants, the primary text colour is the exact RGB inverse of the theme background.

The bundled Makima video was supplied from a Klickpin source. The original creator/source attribution should be retained according to that source when redistributing the asset; the repository does not claim ownership of the video.

Select them from:

```text
SUPER + W → Select Theme → makima-dark
SUPER + W → Select Theme → makima-light
```

# Wallpaper system

Image wallpapers are managed by `awww`. Video wallpapers are managed by `mpvpaper`.

Wallpapers live in:

```text
.config/wallpapers/
```

The wallpaper selector generates cached thumbnails so Rofi can display the library without decoding every full-size asset repeatedly. Video wallpapers use FFmpeg frame extraction for thumbnails and Wallust sampling.

For video playback, the wallpaper script selects `nvdec` only when the NVIDIA kernel driver is actually active; otherwise it uses the automatic decoder path.

The active wallpaper scripts are under:

```text
.config/hypr/scripts/wallpapers/
```

---

# Native helper programs

The `src/` directory contains the small native programs used by NKS. The `Makefile` performs a preflight check for the compiler, `pkg-config`, the Wayland client development files, and `nlohmann/json.hpp` before building.

Build them manually with:

```bash
make clean
make -j"$(nproc)"
```

The installer performs the same build as part of installation.

---

# Troubleshooting

## Hyprland does not start

Check configuration errors:

```bash
hyprctl configerrors
```

Check that the Lua entrypoint exists:

```bash
ls -l ~/.config/hypr/hyprland.lua
```

If you are troubleshooting a newly installed graphics driver, reboot first so the kernel module and DRM state are rebuilt and loaded.

## Native helper build fails

The build requires `base-devel`, `pkgconf`/`pkg-config`, Wayland client development files, and the `nlohmann-json` headers. The Arch package manifest includes the NKS build dependencies.

Run:

```bash
make clean
make -j"$(nproc)"
```

## AUR helper problems

Check:

```bash
command -v paru
command -v yay
```

When neither helper is present, rerun the NKS installer; it is designed to build `yay` as the normal user.

## NVIDIA system after installation

Inspect the selected profile:

```bash
nks-gpu-info
cat ~/.cache/nekoroshell/gpu-profile
cat ~/.cache/nekoroshell/detected-gpus.txt
```

For DKMS failures, verify the running kernel has a matching build tree:

```bash
ls -ld /usr/lib/modules/"$(uname -r)"/build
```

## Existing dotfiles

Use `--replace-existing` only when you have deliberately chosen NKS to own the active Hyprland configuration. The installer creates a backup before replacement.

---

# Updating

NKS is distributed as a Git repository rather than a native Arch package. To update it, pull a newer revision and rerun the installer. Review existing configuration first; use `--replace-existing` when the current dotfiles need to be replaced.

The installer can show its planned actions without modifying the machine:

```bash
./install.sh --dry-run
```

---

# Repository layout

```text
install.sh                     installer and hardware detection
Makefile                       native helper build
README.md                      project documentation
THEMING.md                     skin/theme development notes
CHANGELOG.md                   upstream project history
LICENSE                        project license

.config/hypr/                  Hyprland, Hyprlock, wallpapers, Lua skins
.config/waybar/                navbar
.config/rofi/                  launcher
.config/swaync/                notifications and control centre
.config/wlogout/               power menu
.config/themes/                complete theme bundles
.config/wallpapers/            image and video wallpaper library
.config/wallust/               Wallust configuration

bin/                           user-facing commands
scripts/                       system integration helpers
src/                            native helper source
home/                           files installed into the user's home directory
packages/                      Arch official/AUR manifests
showcase/                      screenshots and navbar examples
.github/                       repository automation and contribution files
```

Only the files required by the standalone Arch repository are kept here. Historical package manifests for other distributions and temporary backup files are intentionally not part of this tree.

---

# Credits and attribution

## NeKoRoSHELL

NeKoRoSHELL was created by **NeKoRoSYS**. This standalone repository is based on the NeKoRoSHELL 1.6 project and retains the upstream project's identity, design direction, structure, and applicable credits.

Upstream project:

- https://github.com/NeKoRoSYS/NeKoRoSHELL

## Upstream project credits

The original project credits the following contributors and sources:

- **JaKooLit / Hyprland-Dots** — inspiration and reference for parts of the desktop configuration.
  - https://github.com/JaKooLit/Hyprland-Dots
- **Amelie (@S-e-r-a-p-h-i-n-e)** — assistance with the transition from pywal16 to Wallust and reuse of selected scripts.
  - https://github.com/S-e-r-a-p-h-i-n-e/SeraDOTS
- **April** — assistance in diagnosing the historical keybinding issue.
- **@MiroBG** — assistance with repository issue tracking and debugging.
- **justinmdickey / publicdots** — source/reference for the Hyprlock design material.
  - https://github.com/justinmdickey/publicdots
- **mkhmtolzhas / mkhmtdots** — source/reference for visual design work used by the legacy styling.
  - https://github.com/mkhmtolzhas/mkhmtdots

## External projects

NKS depends on and/or integrates with independent projects including:

- Hyprland
- Waybar
- SwayNC
- Rofi
- Kitty
- awww
- Wallust
- Hyprshot
- mpvpaper
- mpvpaper-stop
- wlogout
- PipeWire / WirePlumber
- Oh My Posh
- Nautilus
- Qt6 / GStreamer
- `nlohmann-json`
- Qylock

External projects retain their own licenses and attribution requirements. NKS does not claim ownership of third-party code, assets, or projects.

---

# License

NeKoRoSHELL is distributed under the **GNU General Public License v3.0** as provided by the project repository and this repository's `LICENSE` file. Third-party components and bundled assets may have separate licenses.

Read the full license before redistributing a modified copy:

```text
LICENSE
```

## Desktop applications

The standard installation includes Nautilus as the file manager, GNOME Text Editor, GNOME Calculator, GNOME Disk Utility, GNOME System Monitor, GNOME Control Center, GNOME Clocks, File Roller, Loupe, and the GTK/GVFS components needed for local and network file browsing. These are standalone desktop applications; NKS does not install a full GNOME desktop session. `nwg-displays` provides a graphical display configuration utility and `nwg-look` provides GTK appearance controls.

Useful default bindings include `SUPER + E` for a new Nautilus window, `SUPER + ALT + M` for display configuration, `SUPER + ALT + N` for the text editor, and `SUPER + W` for the NKS customization menu.


## Display and Intel graphics

NKS does not install a proprietary display driver for Intel laptops. Modern Arch uses the Linux kernel DRM driver together with Mesa; Vulkan support is provided by `vulkan-intel`, while `intel-media-driver` supplies VA-API support for supported Intel generations. On Intel laptops the Linux kernel exposes the display controller through its DRM driver (commonly `i915` on the generations supported by this repository); there is normally no separate proprietary display driver to install. The installer detects connected DRM outputs and generates `~/.config/hypr/hardware.lua` with preferred-mode monitor rules. A generic preferred-mode fallback remains in the base Hyprland Lua configuration.
