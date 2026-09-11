# CONTRIBUTING

Contributions to the standalone Arch Linux / Hyprland repository are welcome.

Before changing the repository, keep the source tree coherent as one deployable dotfiles project. In particular:

- Keep `install.sh`, `.config/`, `bin/`, `scripts/`, `src/`, `home/`, and the Arch package manifests consistent with one another.
- Do not add distribution-specific package manifests or installers to this repository unless the project direction explicitly changes.
- Do not introduce absolute home-directory paths or machine-specific usernames into shipped configuration.
- Keep Hyprland configuration compatible with the Lua-based configuration used by the repository.
- When changing package requirements, update the Arch manifests and the relevant documentation together.
- When changing a selector, skin, theme, or runtime script, verify that every referenced file exists in a clean checkout.

For native helper changes, run:

```bash
make clean
make -j"$(nproc)"
```

For shell changes, run `bash -n` on the affected scripts. The GitHub Actions workflow also performs repository-wide Bash syntax validation and the native C++ preflight/build checks.

When submitting a change, describe any new dependency, configuration path, hardware-specific behaviour, or external project integration it introduces.

All third-party material must retain the applicable attribution and licensing requirements. See `README.md` and `LICENSE` for the current project credits and license information.
