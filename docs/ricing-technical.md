# Ricing Technical Reference

This document contains the technical notes for the macOS Catppuccin ricing setup. The root README stays focused on practical commands, keybindings and daily usage.

## Architecture

- **AeroSpace** is the tiling window manager.
- **SketchyBar** is the top bar, implemented in Lua/SbarLua.
- **Kitty** is the terminal.
- **Neovim** is the control centre for theme switching.
- **Karabiner-Elements** provides Kitty-scoped Caps-as-Escape/Hyper plus physical-Hyper shortcuts.
- **JankyBorders** draws subtle Catppuccin focus borders.
- **SketchyVim** can be toggled as part of the session.
- **Starship, Yazi, lazygit, zoxide, eza, bat, fzf and delta** provide the terminal workflow.

The setup is deliberately plain files plus shell scripts. There is no Stow/chezmoi layer.

## Runtime State

Runtime state lives under:

- `~/.config/ricing/theme`
- `~/.config/ricing/session_enabled`
- `~/.config/ricing/previous_wallpaper`
- `~/.config/ricing/previous_desktop_icons`
- `~/.config/ricing/previous_kitty_opacity`
- `~/.local/state/nvim/color_theme.txt`
- `~/.local/state/nvim/catppuccin_flavour.txt`

The main session script is:

```sh
~/.config/scripts/catppuccin-session.sh
```

It starts or stops AeroSpace, SketchyBar, wallpaper/theme sync, Kitty opacity, JankyBorders, SketchyVim preference and desktop icon visibility.

## Installed Software And Purpose

Core:

- `aerospace`: tiling window manager.
- `sketchybar`: top bar.
- `kitty`: terminal.
- `borders`: JankyBorders focus borders.
- `svim`: SketchyVim.
- `karabiner-elements`: keyboard remapping.
- `nowplaying-cli`: Apple Music / Now Playing integration.
- `brightness`: display brightness percentage and scroll control where the display supports it.

Terminal tools:

- `starship`: prompt.
- `yazi`: terminal file manager.
- `lazygit`: Git UI.
- `git-delta`: nicer diffs in lazygit.
- `zoxide`: smarter `cd`.
- `eza`: modern `ls`.
- `bat`: modern `cat`.
- `fzf`: fuzzy finder.

## AeroSpace Design

Config:

```sh
~/.config/aerospace/aerospace.toml
```

Layout philosophy:

- Default layout is `tiles` with automatic orientation.
- Halves and balanced quarters are preferred over constant thirds.
- Quarter layouts are shaped with explicit vertical/horizontal splits, movement, joins and balance commands.
- AeroSpace does not provide true drag-to-corner quarter snapping in this build.
- Smooth WM animation is limited by AeroSpace itself. The setup avoids fragile animation hacks; visual polish comes from SketchyBar animations, glass/blur, wallpaper and borders.

Notable config decisions:

- `exec-on-workspace-change` triggers SketchyBar workspace updates.
- `persistent-workspaces` keeps workspaces 1-9 addressable.
- Gaps reserve room for the top bar.
- System Settings and Finder utility dialogs float.

## SketchyBar Architecture

Config:

```sh
~/.config/sketchybar/
```

Important files:

- `sketchybarrc`: loader.
- `init.lua`: Lua entrypoint.
- `bar.lua`: top bar size, blur and glass colour.
- `default.lua`: default item styling.
- `colors.lua`: shared Catppuccin palette and alpha values.
- `icons.lua`: SF Symbols/Nerd Font icon table.
- `settings.lua`: font and spacing settings.
- `items/spaces.lua`: AeroSpace workspace indicators and workspace app icons.
- `items/menus.lua`: macOS menu/title area.
- `items/media.lua`: Apple Music / Now Playing.
- `items/widgets/*.lua`: right-side widgets.

Widgets:

- Workspaces 1-4 are shown by default.
- Workspaces 5-9 appear progressively as higher workspaces are used.
- Workspace labels show app icons when practical.
- Focused app is shown.
- Apple Music shows artwork, title and artist while playing, with popup controls for previous/play-pause/next.
- Volume shows icon and percent, with output-device popup if `SwitchAudioSource` is available.
- Network shows active interface, upload/download, and a popup with interface, hostname, IP and router.
- CPU graph and percentage.
- Memory percentage.
- Brightness percentage and scroll control.
- Weather through `wttr.in`.
- SketchyVim status/toggle.
- Calendar/time.

Weather:

```sh
export SKETCHYBAR_WEATHER_LOCATION=London
```

Brightness:

- Uses the `brightness` CLI.
- Scroll adjusts in 5% steps.
- Click opens Displays settings.
- Unsupported external displays degrade to `--%`.

Manual commands:

```sh
sketchybar --reload
launchctl kickstart -k "gui/$(id -u)/com.kianconti.sketchybar"
launchctl bootout "gui/$(id -u)/com.kianconti.sketchybar"
```

## Theme System

The primary theme control path is Neovim:

- `<leader>cc`: open the colour theme picker.
- `<leader>cS`: toggle the whole Catppuccin session.
- `<leader>ct`: enter Catppuccin tiling mode.
- `:ColorTheme`: open the same picker.
- `:CatppuccinSessionToggle`: toggle the full session.
- `:CatppuccinTilingMode`: enter tiling mode.
- `:CatppuccinTilingRestore`: restore the previous desktop mode.
- `:KittyOpacity`: prompt for Kitty opacity.

When a Catppuccin theme is applied, the setup syncs:

- Neovim colourscheme.
- Kitty colour theme.
- Kitty background opacity.
- SketchyBar colours.
- JankyBorders colours.
- Wallpaper.
- Desktop icon visibility.

The scripts are:

- `scripts/catppuccin-session.sh`: full on/off session manager.
- `scripts/catppuccin-tiling-mode.sh`: theme, wallpaper, desktop icons, SketchyBar colour export and opacity.
- `scripts/kitty-opacity.sh`: safe Kitty opacity writer/reloader.
- `scripts/jankyborders.sh`: themed borders.
- `scripts/sketchyvim-toggle.sh`: SketchyVim runtime preference.

Default tiling opacity is 70%. It can be overridden:

```sh
CATPPUCCIN_TILING_OPACITY=75 ~/.config/scripts/catppuccin-session.sh on mocha
```

## Kitty

Files:

```sh
~/.config/kitty/kitty.conf
~/.config/kitty/current-theme.conf
```

Notable behaviour:

- Catppuccin colours are written to `current-theme.conf`.
- Opacity is controlled by `scripts/kitty-opacity.sh`.
- Live Kitty opacity reload uses `kitty @ set-background-opacity --all` when possible.

## Terminal Workflow

Shell glue:

```sh
~/.config/zsh/ricing.zsh
```

`~/.zshrc` sources that file at the end. It adds:

- Starship prompt.
- zoxide init.
- Catppuccin fzf colours.
- `eza` aliases: `ls`, `ll`, `la`, `lt`.
- `bat` alias for `cat`.
- `lg` for lazygit.
- `yy` helper to exit Yazi into the selected directory.

Yazi:

```sh
~/.config/yazi/yazi.toml
~/.config/yazi/theme.toml
```

lazygit:

```sh
~/.config/lazygit/config.yml
```

Starship:

```sh
~/.config/starship.toml
```

## Karabiner

Config:

```sh
~/.config/karabiner/karabiner.json
```

Caps Lock is intentionally Kitty-scoped:

- Tap Caps in Kitty: Escape.
- Hold Caps in Kitty: Hyper.
- Outside Kitty: normal Caps Lock.

Physical `Control+Option+Command+Shift` works as Hyper globally.

## JankyBorders

Script:

```sh
~/.config/scripts/jankyborders.sh
```

Commands:

```sh
~/.config/scripts/jankyborders.sh apply mocha
~/.config/scripts/jankyborders.sh toggle
~/.config/scripts/jankyborders.sh off
~/.config/scripts/jankyborders.sh status
```

Colours follow the active Catppuccin flavour. The session script suspends borders when turning the rice off without permanently losing the preference.

## Startup

The Catppuccin session helper is represented by:

```sh
~/.config/ricing/com.kianconti.catppuccin-session.plist
~/Library/LaunchAgents/com.kianconti.catppuccin-session.plist
```

At login it checks:

```sh
~/.config/ricing/session_enabled
```

If the value is `1`, it starts the session. If the value is `0`, it keeps the ricing runtime off.

## Reinstall Notes

Clone:

```sh
git clone https://github.com/KitcatCatlord/dotfiles.git ~/dotfiles
```

Install:

```sh
brew install aerospace sketchybar borders nowplaying-cli brightness starship yazi lazygit git-delta zoxide eza bat fzf btop tmux
brew install --cask kitty karabiner-elements
```

Restore configs:

```sh
mkdir -p ~/.config
cp -R ~/dotfiles/aerospace ~/.config/
cp -R ~/dotfiles/sketchybar ~/.config/
cp -R ~/dotfiles/kitty ~/.config/
cp -R ~/dotfiles/nvim ~/.config/
cp -R ~/dotfiles/karabiner ~/.config/
cp -R ~/dotfiles/scripts ~/.config/
cp -R ~/dotfiles/yazi ~/.config/
cp -R ~/dotfiles/lazygit ~/.config/
cp -R ~/dotfiles/zsh ~/.config/
cp -R ~/dotfiles/wallpapers ~/.config/
cp -R ~/dotfiles/borders ~/.config/
cp -R ~/dotfiles/svim ~/.config/
cp ~/dotfiles/starship.toml ~/.config/starship.toml
```

Start:

```sh
~/.config/scripts/catppuccin-session.sh on mocha
```

## Verification Checklist

```sh
ruby -rjson -e 'JSON.parse(File.read(File.expand_path("~/.config/karabiner/karabiner.json"))); puts "karabiner ok"'
python3 - <<'PY'
import tomllib
tomllib.load(open("/Users/kianconti/.config/aerospace/aerospace.toml", "rb"))
print("aerospace toml ok")
PY
find ~/.config/sketchybar -name '*.lua' -print0 | xargs -0 luac -p
zsh -n ~/.config/zsh/ricing.zsh
yazi --version
lazygit --version
delta --version
starship explain
```

Live reloads:

```sh
sketchybar --reload
aerospace reload-config
```
