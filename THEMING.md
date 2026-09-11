# Theming

The theming system is part of the same Hyprland dotfiles tree. The main tools are:

- `bin/customize` — selects and applies an individual skin or theme.
- `bin/quick-theme` — applies a complete theme combination in one operation.
- `.config/hypr/scripts/wallpapers/` — wallpaper, colour, and video-wallpaper helpers.
- `.config/themes/<theme>/` — complete theme entrypoints.

The repository is designed so these pieces work together from one installed tree under the user's home directory.

## Wallpapers

Wallpapers live in `.config/wallpapers/` and are discovered recursively, so subdirectories may be used to organize larger collections.

Runtime wallpaper thumbnails and other temporary state are stored under the user's cache directory, normally:

```text
~/.cache/nekoroshell/
```

Image wallpapers are managed by `awww`; animated wallpapers are managed by `mpvpaper`. Video thumbnails and colour sampling use FFmpeg-based frame extraction so the full video does not need to be decoded for every selection.

## Making a skin

The general structure is:

```text
.config/<component>/skins/<skin>/...
```

Inspect the existing component directories before creating a new skin. The required files differ by component.

### Waybar navbar skins

```text
.config/waybar/skins/<skin>/
```

A navbar skin normally provides:

- `style.css`
- `layout.jsonc`
- `navbar-hover.conf`

The root `.config/waybar/config.jsonc` and `.config/waybar/style.css` are switched by `customize`.

`navbar-hover.conf` is copied to:

```text
~/.cache/nekoroshell/navbar-hover.conf
```

The native `navbar-hover` helper reads that file. The visibility positions are `top`, `bottom`, `left`, or `right`; keep the activation threshold below the deactivation threshold to avoid rapid toggling.

### Rofi launcher skins

```text
.config/rofi/skins/<skin>/
```

A Rofi skin provides:

- `config.rasi`
- `style.rasi`

The files may use the skin's local Wallust colour cache rather than a hard-coded absolute path.

### Hyprlock skins

```text
.config/hypr/hyprlock/skins/<skin>/
```

The root Hyprlock configuration selects the active skin. Keep the skin self-contained so it can be copied as part of the same dotfiles tree.

### SwayNC control-centre skins

```text
.config/swaync/skins/<skin>/
```

A SwayNC skin normally provides:

- `config.json`
- `style.css`

`config.json` is copied into the active SwayNC configuration because JSON itself does not provide the same import mechanism used by CSS. `style.css` is switched to the selected skin.

### Wlogout power skins

```text
.config/wlogout/skins/<skin>/
```

A power skin normally provides:

- `layout`
- `style.css`
- any required assets under the skin's `assets/` directory

### Hyprland window skins

Hyprland 0.55+ uses the native Lua configuration path in this repository. Window skins are therefore individual Lua files:

```text
.config/hypr/nks-window-skins/<skin>.lua
```

The selector discovers every `.lua` file in that directory. The active filename is stored in:

```text
~/.cache/nekoroshell/window_skin
```

The main `.config/hypr/hyprland.lua` loads the selected skin when Hyprland starts or reloads. This keeps the window styling inside the current Lua configuration rather than generating a separate legacy compositor configuration.

## Standalone colour handling

Supported skins keep their own local Wallust colour cache, such as:

```text
colors-wallust.css
colors-wallust.rasi
```

`.config/hypr/scripts/wallpapers/apply-colors.sh` updates these local cache files when Wallust regenerates colours. Avoid hard-coded usernames and absolute home-directory paths in skins; use `$HOME`, XDG paths, or the repository's existing relative layout.

## Making a theme

Themes live in:

```text
.config/themes/<theme>/
```

A theme is a directory containing a Bash entrypoint. The normal pattern is:

```bash
#!/usr/bin/env bash
set -euo pipefail

quick-theme WALLPAPER_SKIN NAVBAR_SKIN LAUNCHER_SKIN LOCKSCREEN_SKIN PANEL_SKIN POWER_SKIN WINDOWS_SKIN
```

Replace the placeholders with actual shipped skin names. Additional logic may be added when a theme needs special wallpaper handling, palette selection, or component-specific setup.

## Makima themes

The repository includes `makima`, `makima-dark`, and `makima-light` themes and the bundled video wallpaper:

```text
.config/themes/makima/makima.sh
.config/wallpapers/makima.mp4
```

It also includes a dedicated dark and light Hyprlock skins and a palette helper. `makima-dark` uses a near-black/deep-red palette; `makima-light` uses a pale warm background with dark text and restrained red accents. Both variants keep the primary text colour as the exact RGB inverse of the selected background so asynchronous wallpaper colour processing cannot change the selected palette.

The bundled Makima video was supplied from a Klickpin source. Preserve the original creator/source attribution required by that source when redistributing the asset.

## Validation checklist

Before committing a new skin or theme, verify:

1. Every file referenced by the selector actually exists.
2. No skin contains a machine-specific username or absolute home path.
3. The selected root configuration still points to the skin after a reload.
4. The component can be restarted or reloaded without manual file copying outside the repository's documented runtime cache.
5. The theme works from a clean checkout as one coherent dotfiles tree.

For the shipped selectors, `bin/customize` discovers the available skins from the directories themselves, so adding a correctly structured skin is sufficient to make it selectable.
