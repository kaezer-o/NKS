# NeKoRoSHELL

**NeKoRoSHELL** is a standalone Hyprland desktop configuration for Arch Linux, built around a keyboard-driven workflow, modular theming, desktop utilities, hardware detection, and extensive customization.

## Features

- Hyprland-based Wayland desktop
- Keyboard-first workflow
- Dynamic wallpaper-based color generation
- Multiple Waybar skins
- Multiple Rofi skins
- Multiple SwayNC skins
- Multiple Wlogout skins
- Multiple Hyprlock skins
- Multiple Hyprland window skins
- Built-in NeKoRoSHELL customization interface
- GTK appearance management
- Display configuration with `nwg-displays`
- Nautilus file manager integration
- GNOME desktop utilities
- Kitty + Zsh terminal environment
- Hardware-aware monitor configuration
- Intel, AMD, and NVIDIA graphics detection
- NVIDIA driver selection based on GPU generation
- Qylock integration with SDDM
- Atomic theme and palette generation
- Modular configuration structure
- Automatic package and dependency handling
- Arch Linux focused installation

## Installation

### 1. Install Arch Linux

Install a working Arch Linux system using the standard Arch installation process or `archinstall`.

A normal user account with `sudo` access is recommended.

### 2. Clone NeKoRoSHELL

```bash
git clone <REPOSITORY_URL>
cd NeKoRoSHELL
```

### 3. Run the installer

```bash
bash install.sh
```

For unattended installation:

```bash
bash install.sh --no-confirm
```

The installer detects the available user, hardware, graphics hardware, and required packages, then deploys the NeKoRoSHELL configuration.

### 4. Reboot

```bash
reboot
```

Log into the configured Hyprland session from your display manager.

## Keybindings

The following are the primary NeKoRoSHELL bindings.

| Key | Action |
|---|---|
| `SUPER + Enter` | Open Kitty |
| `SUPER + E` | Open Nautilus |
| `SUPER + W` | Open NeKoRoSHELL customization |
| `SUPER + M` | Maximize active window |
| `SUPER + ALT + M` | Open display configuration |
| `SUPER + ALT + N` | Open GNOME Text Editor |
| `SUPER + CTRL + Enter` | Application launcher |
| `SUPER + ALT + C` | Run launcher |
| `SUPER + SHIFT + C` | Game launcher |
| `SUPER + CTRL + K` | Show keybindings |
| `SUPER + CTRL + P` | Power menu |
| `SUPER + SHIFT + W` | Random wallpaper |
| `SUPER + CTRL + W` | Wallpaper selector |

Hyprland workspace, window-management, media, system, and navigation bindings are also included.

## Customization

The main customization interface is available through:

```text
SUPER + W
```

The customization system provides access to the available visual configurations and skins.

Configuration components are kept modular so individual parts can be modified without rebuilding the entire desktop.

## Themes

NeKoRoSHELL includes independent theme collections for:

- Hyprland
- Hyprlock
- Waybar
- Rofi
- SwayNC
- Wlogout
- GTK
- Kitty
- Cursor
- Wallpaper-generated colors

### Makima

Two Makima themes are included:

- Makima Dark
- Makima Light

The included Makima video asset is:

```text
makima.mp4
```

## Applications

NeKoRoSHELL integrates a collection of desktop applications and utilities, including:

- Kitty
- Zsh
- Nautilus
- GNOME Text Editor
- GNOME Calculator
- GNOME System Monitor
- GNOME Disk Utility
- GNOME Control Center
- GNOME Clocks
- File Roller
- Loupe
- Rofi
- Waybar
- SwayNC
- Wlogout
- `nwg-look`
- `nwg-displays`

## Hardware Support

NeKoRoSHELL includes hardware detection and configuration for common graphics hardware.

### Intel

Mesa and Vulkan support are configured for supported Intel graphics.

### AMD

Mesa and Vulkan support are configured for supported AMD graphics.

### NVIDIA

NVIDIA hardware is detected during installation and an appropriate driver family is selected according to the GPU generation.

The configuration is intended to work with both integrated and discrete graphics systems.

## Project Structure

```text
NeKoRoSHELL/
├── .config/
│   ├── hypr/
│   ├── kitty/
│   ├── rofi/
│   ├── swaync/
│   ├── themes/
│   ├── waybar/
│   └── wlogout/
│
├── bin/
├── home/
├── packages/
├── scripts/
├── src/
├── install.sh
├── Makefile
└── README.md
```

## Fonts

The default configuration uses:

- JetBrains Mono Nerd Font
- Font Awesome
- Bibata Modern Ice cursor

These can be replaced with other fonts and cursor themes.

## Requirements

NeKoRoSHELL is primarily developed and tested on:

- Arch Linux
- Wayland
- Hyprland

Hardware, package availability, display drivers, and third-party components may behave differently on other systems.

## Credits

NeKoRoSHELL uses and integrates software from the following projects.

### Hyprland

The core Wayland compositor.

https://github.com/hyprwm/Hyprland

### Rofi

Used for application launching and the customization interface.

https://github.com/davatorium/rofi

### Waybar

Used for the desktop panel and system information.

https://github.com/Alexays/Waybar

### SwayNotificationCenter

Used for desktop notifications.

https://github.com/ErikReider/SwayNotificationCenter

### Wlogout

Used for the power menu.

https://github.com/ArtsyMacaw/wlogout

### Kitty

Used as the terminal emulator.

https://github.com/kovidgoyal/kitty

### Zsh

Used as the interactive shell.

https://www.zsh.org/

### Wallust

Used for wallpaper-based color generation.

https://codeberg.org/explosion-mental/wallust

### nwg-shell

Used for utilities including `nwg-look` and `nwg-displays`.

https://github.com/nwg-piotr

### Qylock

Used for the SDDM lockscreen integration.

**Qylock by Darkkal44**

https://github.com/Darkkal44/Qylock

### GNOME

GNOME applications are used for common desktop utilities.

https://www.gnome.org/

## Acknowledgements

Special thanks to the developers and contributors of the projects listed above and to the wider Linux, Arch Linux, Wayland, and Hyprland communities.

Additional inspiration and reference material for parts of NeKoRoSHELL came from the work of:

- JaKooLit
- S-e-r-a-p-h-i-n-e
- April
- MiroBG
- justinmdickey
- mkhmtolzhas

Their work influenced parts of the configuration, workflow, scripting approaches, visual design, and experimentation that ultimately contributed to NeKoRoSHELL.

NeKoRoSHELL does not claim ownership of third-party software, code, themes, assets, or design concepts belonging to their respective authors.

## Third-Party Licenses

Third-party software, themes, fonts, icons, scripts, wallpapers, and other external assets remain subject to their respective licenses.

Please refer to the original project repositories and included license files for the applicable terms.

## License

NeKoRoSHELL is an independent configuration project.

The licensing terms of NeKoRoSHELL apply only to material authored specifically for this project. Third-party components remain under their original licenses.

---

**NeKoRoSHELL**
