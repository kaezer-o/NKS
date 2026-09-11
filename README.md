<div align="center">

# NeKoRoSHELL

A modular Hyprland desktop configuration focused on clean theming, practical defaults, and reproducible installation.

![Hyprland](https://img.shields.io/badge/WM-Hyprland-00A4FF?style=for-the-badge)
![Arch Linux](https://img.shields.io/badge/Primary%20Target-Arch%20Linux-1793D1?style=for-the-badge)
![License](https://img.shields.io/github/license/NeKoRoSYS/NeKoRoSHELL?style=for-the-badge)

</div>

---

## Overview

NeKoRoSHELL is a standalone Hyprland desktop configuration and customization framework.

It provides:

- Hyprland configuration and keybindings
- Waybar navbar
- Rofi application launcher and customization menus
- SwayNC notification/control panel
- Hyprlock lockscreen
- Wlogout power menu
- Kitty terminal
- Wallust-based dynamic color generation
- Wallpaper management with `awww`
- Animated wallpaper support with `mpvpaper`
- Modular component skins
- Complete desktop themes
- Hardware-aware graphics configuration
- Automatic monitor detection
- SDDM integration with Qylock
- Zsh configuration
- GNOME desktop utilities without installing a complete GNOME session

The primary and tested installation target is Arch Linux.

---

# Installation

## Requirements

Start with a working Arch Linux installation.

The installer expects:

- `sudo`
- `git`
- a normal non-root user
- working network access
- a configured Arch package repository

The installer can be run directly from the repository.

```bash
git clone https://github.com/NeKoRoSYS/NeKoRoSHELL.git
cd NeKoRoSHELL
