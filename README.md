# Dotfiles

My cross-platform terminal and editor configuration.

## Included

- `nvim/`: Neovim configuration and colour-theme controls.
- `kitty/`: Kitty configuration and active theme.
- `karabiner/`: macOS keyboard rules.
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

## Kitty Opacity

```sh
~/.config/scripts/kitty-opacity.sh 70
~/.config/scripts/kitty-opacity.sh 100
```

The retired macOS rice is preserved for reference on the
`archive/macos-catppuccin-rice-2026-07-27` branch.
