# Linux Neovim Dotfiles

Portable Neovim configuration and Linux installer. This branch contains no desktop, terminal, shell, window-manager, or other platform configuration.

## Install

From a Linux checkout:

```sh
./linux-setup.sh --backup-existing-config
```

Installer detects `apt`, `dnf`, `yum`, `pacman`, or `zypper`; installs Neovim 0.11+, Node.js 18+, Python, Lua, .NET 10, compiler tools, language servers, formatters, debuggers, and command-line dependencies; restores plugins and Treesitter parsers; installs Mason packages; and writes a health log.

Existing `~/.config/nvim` is never overwritten by default. Use `--backup-existing-config` to move it to `$XDG_STATE_HOME/nvim-setup/backups/`, or `--no-config-install` to run setup against the repository copy without installing it.

Useful options:

```sh
./linux-setup.sh --help
./linux-setup.sh --dry-run --no-config-install
./linux-setup.sh --config-dir "$HOME/.config/nvim" --backup-existing-config
```

## Included

- `nvim/`: Neovim configuration, plugin lockfile, local modules, and setup script.
- `linux-setup.sh`: safe entrypoint that installs the configuration and dependencies.
- `LICENSE`: repository license.

## Verification

```sh
bash -n linux-setup.sh
bash -n nvim/setup.sh
luac -p nvim/init.lua
./linux-setup.sh --dry-run --no-config-install
```
