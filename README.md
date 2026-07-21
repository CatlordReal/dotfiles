# Linux Neovim Dotfiles

Portable Neovim configuration and Linux installer. Optional CLI setup adds tmux, a shell tool bundle, JetBrainsMono Nerd Font, and Powerlevel10k.

## Install

From a Linux checkout:

```sh
./linux-setup.sh --backup-existing-config
```

Installer detects `apt`, `dnf`, `yum`, `pacman`, or `zypper`; installs Neovim 0.11+, Node.js 18+, Python, Lua, .NET 10, compiler tools, language servers, formatters, debuggers, and command-line dependencies; restores plugins and Treesitter parsers; installs Mason packages; and writes a health log.

The default install is Neovim-focused. Add `--with-cli-tools` for tmux, bat, eza, fzf, zoxide, delta, starship, yazi, btop, jq, wget, htop, ncdu, JetBrainsMono Nerd Font, Powerlevel10k, `~/.p10k.zsh`, and `~/.tmux.conf`. The font and shell/tmux files are installed under your home directory only when requested.

Existing `~/.config/nvim` is never overwritten by default. Use `--backup-existing-config` to move it to `$XDG_STATE_HOME/nvim-setup/backups/`, or `--no-config-install` to run setup against the repository copy without installing it.

Useful options:

```sh
./linux-setup.sh --help
./linux-setup.sh --dry-run --no-config-install
./linux-setup.sh --config-dir "$HOME/.config/nvim" --backup-existing-config
./linux-setup.sh --with-cli-tools --backup-existing-config
```

Use `--with-font`, `--with-p10k`, or `--with-tmux` for individual components. Existing auxiliary files are preserved unless `--backup-existing-config` is supplied. Use `--no-aux-config-install` to install the software without copying `.p10k.zsh` or `.tmux.conf`.

## Included

- `nvim/`: Neovim configuration, plugin lockfile, local modules, and setup script.
- `linux-setup.sh`: safe entrypoint that installs the configuration and dependencies.
- `.p10k.zsh`: optional Powerlevel10k prompt configuration.
- `.tmux.conf`: optional tmux configuration.
- `LICENSE`: repository license.

## Verification

```sh
bash -n linux-setup.sh
bash -n nvim/setup.sh
luac -p nvim/init.lua
./linux-setup.sh --dry-run --no-config-install
```
