# Dotfiles

- [Technical ricing reference](docs/ricing-technical.md)

## What Is Here

- `aerospace/`: AeroSpace window manager config.
- `borders/`: JankyBorders LaunchAgent.
- `karabiner/`: keyboard rules.
- `kitty/`: Kitty config and active theme.
- `lazygit/`: lazygit config.
- `nvim/`: Neovim config and theme controls.
- `ricing/`: ricing state helpers and LaunchAgent plist.
- `scripts/`: session, theme, shelf, sound and appearance scripts.
- `sketchybar/`: SketchyBar config and widgets.
- `starship.toml`: prompt config.
- `svim/`: SketchyVim config.
- `yazi/`: Yazi config.
- `zsh/`: shell integration.

## Neovim Controls

- `<leader>cc`: choose colour theme.
- `<leader>cS`: toggle the full Catppuccin tiling session.
- `<leader>ct`: enter Catppuccin tiling mode.
- `<leader>cb`: toggle JankyBorders.
- `:ColorTheme`: open the colour theme picker.
- `:CatppuccinSessionToggle`: toggle the full ricing session.
- `:CatppuccinTilingMode`: enter Catppuccin tiling mode.
- `:CatppuccinTilingRestore`: restore the previous desktop mode.
- `:KittyOpacity`: prompt for Kitty opacity.
- `:JankyBordersToggle`: toggle borders.

## AeroSpace Keys

- `Alt+Enter`: open Kitty.
- `Alt+h/j/k/l`: focus left/down/up/right.
- `Alt+Shift+h/j/k/l`: move focused window left/down/up/right.
- `Alt+-` / `Alt+=`: resize smart smaller/larger.
- `Alt+Shift+-` / `Alt+Shift+=`: larger resize steps.
- `Alt+f`: fullscreen focused window.
- `Alt+Shift+Space`: toggle floating/tiling.
- `Alt+/`: toggle tile orientation.
- `Alt+,`: accordion layout.
- `Alt+v`: force vertical tile orientation.
- `Alt+b`: force horizontal tile orientation.
- `Alt+Shift+b`: balance sizes.
- `Alt+q`: shape a three-window layout as one half plus two quarters.
- `Alt+1` through `Alt+9`: switch workspace.
- `Alt+Shift+1` through `Alt+Shift+9`: move focused window to workspace and follow it.
- `Alt+Tab`: workspace back and forth.
- `Alt+Shift+Tab`: move workspace to next monitor.
- `Alt+Shift+;`: service mode.

Service mode:

- `Esc`: reload AeroSpace config and return to main mode.
- `r`: flatten workspace tree.
- `b`: balance sizes.
- `f`: toggle floating/tiling.
- `v`: force vertical tile orientation.
- `s`: force horizontal tile orientation.
- `h/j/k/l`: resize width/height.
- `Alt+Shift+h/j/k/l`: join with neighbour in that direction.
- `Backspace`: close all windows except current.

## Karabiner And Hyper

Caps Lock is scoped to Kitty only:

- Tap Caps in Kitty: Escape.
- Outside Kitty: normal Caps Lock.
- Right Shift: Hyper (`Control+Option+Command+Shift`).

Hyper shortcuts:

- `Hyper+Enter`: open Kitty.
- `Hyper+M`: open Music.
- `Hyper+F`: open Finder.
- `Hyper+R`: reload all ricing components.
- `Hyper+T`: toggle the full Catppuccin tiling session.
- `Hyper+1` through `Hyper+9`: switch AeroSpace workspace.
- `Hyper+h/j/k/l`: focus left/down/up/right via AeroSpace.
- `Hyper+Arrow keys`: move focused window left/down/up/right via AeroSpace.

Fallback:

- `Control+Option+Command+T`: toggle the full Catppuccin tiling session.


## SketchyVim

- Click the `svim` widget to toggle SketchyVim.
- `~/.config/scripts/sketchyvim-toggle.sh status`: check state.
- `~/.config/scripts/sketchyvim-toggle.sh toggle`: toggle state.
- It turns supported macOS input fields into Vim-like buffers. Use normal Vim movement/editing habits in text fields.
- Current blacklist: Kitty, Terminal, Codex, Code, Neovim-style apps and other terminal editors.
- Current custom remaps: `ß` maps to `$`; `Ctrl+k` and `Ctrl+l` move the current line down/up through the example SketchyVim mappings.

## SketchyBar Controls

- Click the workspace items to switch AeroSpace workspaces.
- Right-click a workspace item to move the focused window there.
- Click Apple Music artwork to show previous/play-pause/next controls.
- Scroll over volume to adjust volume.
- Click volume to show output devices when `SwitchAudioSource` is available.
- Click network to show interface, hostname, IP and router.
- Scroll over brightness to adjust in 5% steps when macOS or DDC exposes the display brightness.
- Click brightness to open Displays settings. On unsupported displays it shows `Display` and acts as a shortcut.
- Click weather to open `wttr.in`.
- Click or hover the appearance gear to open the appearance popup.
- The appearance gear stays visible on empty desktops; noisy telemetry widgets hide when the focused workspace has no windows.
- Click the centre Shelf item to open the shelf folder.
- Right-click or hover the Shelf item to show pinned files.

Appearance popup:

- Choose Catppuccin Latte, Frappe, Macchiato or Mocha.
- Toggle automatic macOS light/dark appearance sync.
- Set Kitty opacity to 60%, 70%, 85% or 100%.
- Toggle subtle UI sounds.
- Toggle the full rice session on/off.
- Reload all: AeroSpace, SketchyBar, JankyBorders, SketchyVim and theme colours.

Shelf:

- The bar cannot receive external file drops in the current SketchyBar build.
- The Shelf item opens a Finder-backed folder at `~/.config/ricing/shelf`.
- Drag files into that folder to keep them in the shelf.
- Drag files out of that folder to remove them.
- Popup rows reveal files in Finder.

Weather location:

```sh
export SKETCHYBAR_WEATHER_LOCATION=London
```

## Theme And Appearance Commands

Full session:

```sh
~/.config/scripts/catppuccin-session.sh on mocha
~/.config/scripts/catppuccin-session.sh off
~/.config/scripts/catppuccin-session.sh toggle
~/.config/scripts/catppuccin-session.sh status
```

Appearance popup backend:

```sh
~/.config/scripts/appearance-control.sh status
~/.config/scripts/appearance-control.sh theme mocha
~/.config/scripts/appearance-control.sh opacity 70
~/.config/scripts/appearance-control.sh toggle-auto
~/.config/scripts/appearance-control.sh toggle-sounds
~/.config/scripts/appearance-control.sh reload
```

Kitty opacity:

```sh
~/.config/scripts/kitty-opacity.sh 70
~/.config/scripts/kitty-opacity.sh 0.70
~/.config/scripts/kitty-opacity.sh 70%
```

Sounds:

```sh
~/.config/scripts/aesthetic-sound.sh status
~/.config/scripts/aesthetic-sound.sh toggle
~/.config/scripts/aesthetic-sound.sh off
```

Shelf:

```sh
~/.config/scripts/shelf.sh open
~/.config/scripts/shelf.sh list
~/.config/scripts/shelf.sh path
```

## Terminal Commands

- `lg`: lazygit.
- `yy`: open Yazi and `cd` to the final directory when it exits.
- `ls`: eza with icons.
- `ll`: long eza listing with Git info.
- `la`: all files with eza.
- `lt`: shallow eza tree.
- `cat`: bat without paging.


## Native Menu Bar

SwiftBar is installed for a normal macOS menu-bar control. It uses `~/.config/swiftbar/catppuccin-rice.1m.sh` and exposes rice toggle, reload all, Catppuccin themes and Kitty opacity.

## Manual Reloads

```sh
sketchybar --reload
aerospace reload-config
~/.config/scripts/jankyborders.sh toggle
```

Apple Terminal windows are automatically floated by AeroSpace. Kitty stays tiled. True always-on-top is not exposed by this AeroSpace build, so the setup avoids a fragile focus loop.

## Verification

```sh
ruby -rjson -e 'JSON.parse(File.read(File.expand_path("~/.config/karabiner/karabiner.json"))); puts "karabiner ok"'
python3 - <<'PY'
import tomllib
tomllib.load(open("/Users/kianconti/.config/aerospace/aerospace.toml", "rb"))
print("aerospace toml ok")
PY
find ~/.config/sketchybar -name '*.lua' -print0 | xargs -0 luac -p
zsh -n ~/.config/zsh/ricing.zsh
zsh -n ~/.config/scripts/appearance-control.sh ~/.config/scripts/aesthetic-sound.sh ~/.config/scripts/shelf.sh
yazi --version
lazygit --version
delta --version
starship explain
```

Docs generated by ChatGPT Codex.
