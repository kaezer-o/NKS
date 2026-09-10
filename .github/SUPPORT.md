> [!WARNING]
> This repository targets a standalone Arch Linux installation using Hyprland. Package versions and upstream projects can change over time, so a configuration that worked on one installation may require adjustment after a system upgrade.

# Support / Troubleshooting

## First checks

Confirm the repository was installed as intended:

```bash
command -v hyprland
command -v waybar
command -v swaync
ls -l ~/.config/hypr/hyprland.lua
```

For graphics-related problems:

```bash
nks-gpu-info
cat ~/.cache/nekoroshell/gpu-profile
cat ~/.cache/nekoroshell/detected-gpus.txt
```

For Hyprland configuration errors:

```bash
hyprctl configerrors
```

## Keybindings do not work

The active bindings are defined by:

```text
~/.config/hypr/hyprland.lua
```

The repository's command directory is:

```text
~/.local/bin/nekoroshell/
```

Check that it is present and readable:

```bash
ls -la ~/.local/bin/nekoroshell/
```

The installer also places the NKS command directory first in the user's PATH through the Hyprland environment and Zsh configuration.

## Existing dotfiles

The installer intentionally refuses to silently replace an existing Hyprland/dotfiles setup. Use `--replace-existing` only after reviewing the backup and deciding that NKS should become the active configuration.

## Reporting a bug

Include:

1. Arch Linux kernel and Hyprland versions.
2. GPU model and `nks-gpu-info` output.
3. The exact command or keybinding that fails.
4. Relevant output from `hyprctl configerrors` or the terminal running the affected command.
5. Whether the problem occurs on a clean installation or an existing dotfiles replacement.

Do not include passwords, private keys, tokens, or other sensitive information in issue reports.
