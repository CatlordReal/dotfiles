# Dotfiles

My cross-platform terminal and editor configuration.

## Included

- `nvim/`: Neovim configuration and colour-theme controls.
- `kitty/`: Kitty configuration and active theme.
- `karabiner/`: macOS keyboard rules.
- `espanso/`: boundary-aware text expansions that do not fire inside words.
- `alacritty/`, `btop/`, `lazygit/`, `yazi/`: application configuration.
- `.zshrc`, `.p10k.zsh`, `starship.toml`: shell and prompt configuration.
- `scripts/`: general command-line helpers.

## Neovim And Kitty

- `<leader>cc`: choose a colour theme for Neovim and Kitty.
- `<leader>co`: set Kitty background opacity.
- `:ColorTheme`: open the colour-theme picker.
- `:ColorThemeSet catppuccin-mocha`: set a theme directly.
- `:KittyThemeSync`: reapply the current theme to Kitty.
- `:KittyOpacity`: prompt for Kitty opacity.

## Karabiner

- Tap Caps Lock in Kitty: Escape.
- Caps Lock outside Kitty: normal Caps Lock.
- Hold Right Shift: Hyper (`Control+Option+Command+Shift`).
- `Hyper+Enter`: open Kitty.
- `Hyper+M`: open Music.
- `Hyper+F`: open Finder.
- `Hyper+C`: open ChatGPT.
- `Hyper+X`: open Codex.

## Espanso

Install Espanso, then copy the tracked configuration:

```sh
brew install --cask espanso
mkdir -p "$HOME/Library/Application Support/espanso/config" \
  "$HOME/Library/Application Support/espanso/match"
cp espanso/config/default.yml \
  "$HOME/Library/Application Support/espanso/config/default.yml"
cp espanso/match/base.yml \
  "$HOME/Library/Application Support/espanso/match/base.yml"
```

Personal expansions belong in a separate untracked match file.

## Kitty Opacity

```sh
~/.config/scripts/kitty-opacity.sh 70
~/.config/scripts/kitty-opacity.sh 100
```

The retired macOS rice is preserved for reference on the
`archive/macos-catppuccin-rice-2026-07-27` branch.
