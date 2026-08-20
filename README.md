# Kali Linux dotfiles

`linux-setup.sh` installs every Linux-supported configuration in this repository on Kali Linux. It installs missing APT packages, a verified JetBrainsMono Nerd Font when a terminal is selected, configuration files, and Neovim plugins.

```sh
git clone https://github.com/kianconti/dotfiles.git
cd dotfiles
./linux-setup.sh --dry-run
./linux-setup.sh
```

Default components: Neovim, Kitty, Alacritty, btop, Lazygit, Yazi, Zsh, tmux, Powerlevel10k configuration, Starship, and Espanso. Optional packages unavailable in configured APT repositories are reported and skipped; their configuration is still installed.

## Existing dotfiles

Existing targets stay untouched by default. Use `--backup-existing` to move each existing target to a timestamped sibling before installing its replacement. A failed configuration install restores every moved target.

```sh
./linux-setup.sh --components nvim,kitty --backup-existing
./linux-setup.sh --no-packages --no-neovim-bootstrap
```

Use `./linux-setup.sh --help` for all options.

## Existing Neovim colourschemes

Both import modes require the `nvim` component. When `~/.config/nvim` already exists, they also require `--backup-existing` so the source is preserved before replacement.

Copy complete runtime roots into Neovim's data directory for a local snapshot:

```sh
./linux-setup.sh --components nvim --backup-existing --copy-existing-colorschemes
```

Reference existing configuration and Lazy plugin runtime roots without copying them:

```sh
./linux-setup.sh --components nvim --backup-existing --register-existing-colorschemes
```

`--theme-source-config PATH` and `--theme-source-data PATH` select non-default sources. Copy mode preserves symlinks inside each runtime root; register mode keeps absolute source paths. Missing or stale registered roots are skipped safely when Neovim starts.

Imported themes appear under **Imported** in the persistent picker. `<leader>cc`, `<leader>uC`, `:ColorTheme`, and `:ColorThemeSet THEME` change Neovim's colour scheme and sync Kitty's colours. They do not control opacity, wallpaper, a window manager, a top bar, or any other desktop setting.

## Tests

```sh
bash -n linux-setup.sh tests/test-linux-setup.sh tests/test-nvim-colorschemes.sh
tests/test-linux-setup.sh
tests/test-nvim-colorschemes.sh
luac -p nvim/init.lua nvim/lua/imported_colorschemes.lua
zsh -n zshrc
```

Automatic package installation intentionally supports Kali only. `--no-packages` provides a configuration-only path on other Linux distributions. The installer refuses macOS; Neovim and Kitty configuration remains portable and can be installed separately there.
