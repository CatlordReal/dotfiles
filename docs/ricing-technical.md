# Ricing Technical Reference

This document contains implementation notes for the macOS Catppuccin ricing setup. The root README stays focused on commands, keybindings and usage.

## Architecture

- **AeroSpace** is the tiling window manager.
- **SketchyBar** is the top bar, implemented in Lua/SbarLua.
- **Kitty** is the terminal.
- **Neovim** is the control centre for theme switching.
- **Karabiner-Elements** provides Kitty-scoped Caps-as-Escape/Hyper plus physical-Hyper shortcuts.
- **JankyBorders** draws subtle Catppuccin focus borders.
- **SketchyVim** can be toggled as part of the session.
- **Appearance popup** provides common ricing controls from SketchyBar.
- **Shelf** provides a centre bar item backed by a Finder folder for temporary pinned files.
- **Starship, Yazi, lazygit, zoxide, eza, bat, fzf and delta** provide the terminal workflow.

## Runtime State

- `~/.config/ricing/theme`
- `~/.config/ricing/session_enabled`
- `~/.config/ricing/previous_wallpaper`
- `~/.config/ricing/previous_desktop_icons`
- `~/.config/ricing/previous_kitty_opacity`
- `~/.config/ricing/auto_appearance_enabled`
- `~/.config/ricing/sounds_enabled`
- `~/.config/ricing/shelf/`
- `~/.local/state/nvim/color_theme.txt`
- `~/.local/state/nvim/catppuccin_flavour.txt`

## Scripts

- `scripts/catppuccin-session.sh`: full on/off session manager.
- `scripts/catppuccin-tiling-mode.sh`: theme, wallpaper, desktop icons, SketchyBar colour export, Starship palette and Kitty opacity.
- `scripts/kitty-opacity.sh`: safe Kitty opacity writer/reloader.
- `scripts/jankyborders.sh`: themed borders.
- `scripts/sketchyvim-toggle.sh`: SketchyVim runtime preference.
- `scripts/appearance-control.sh`: SketchyBar appearance popup backend.
- `scripts/aesthetic-sound.sh`: quiet optional sound effects.
- `scripts/shelf.sh`: Finder-backed shelf helper.

## SketchyBar

Important files:

- `sketchybarrc`: loader.
- `init.lua`: Lua entrypoint.
- `bar.lua`: top bar size, blur and glass colour.
- `default.lua`: default item styling.
- `colors.lua`: shared Catppuccin palette and alpha values.
- `icons.lua`: SF Symbols/Nerd Font icon table.
- `settings.lua`: font and spacing settings.
- `items/spaces.lua`: AeroSpace workspace indicators and app icons.
- `items/shelf.lua`: centre Shelf item and popup list.
- `items/widgets/appearance.lua`: appearance dropdown, session toggle, reload-all button and status poller.
- `items/media.lua`: Apple Music / Now Playing.
- `items/widgets/*.lua`: right-side widgets.

Widgets:

- Progressive workspace indicators for workspaces 1-9.
- Workspace app icons where practical.
- Focused app.
- Apple Music artwork, title, artist and popup controls.
- Volume, network, CPU, memory, brightness, weather, SketchyVim and calendar.
- Appearance gear with Catppuccin flavour, full rice toggle, auto appearance, Kitty opacity, sound and reload-all controls.
- Centre Shelf item with a Finder-backed folder and popup list.

The running SketchyBar binary exposes click, scroll and hover events, but not a native external file-drop event. The Shelf item uses a real folder at `~/.config/ricing/shelf`; files can be dragged into and out of that folder in Finder while the bar shows count and recent entries.

## Appearance Popup

Backend:

```sh
~/.config/scripts/appearance-control.sh
```

Commands:

```sh
~/.config/scripts/appearance-control.sh status
~/.config/scripts/appearance-control.sh theme mocha
~/.config/scripts/appearance-control.sh opacity 70
~/.config/scripts/appearance-control.sh toggle-auto
~/.config/scripts/appearance-control.sh toggle-sounds
~/.config/scripts/appearance-control.sh reload
```

Status output:

```text
theme=mocha
opacity=0.70
auto=on
sounds=on
session=on
```

Auto appearance sync:

- State file: `~/.config/ricing/auto_appearance_enabled`.
- Enabled by default.
- The SketchyBar appearance widget checks periodically.
- If the ricing session is on, macOS Light maps to Catppuccin Latte and macOS Dark maps to Catppuccin Mocha.
- macOS sunset schedules work indirectly by changing system appearance; the next poll syncs the theme.

## Theme Sync

Catppuccin themes sync across:

- Neovim.
- Kitty.
- SketchyBar.
- JankyBorders.
- Wallpaper.
- Desktop icon visibility.
- Kitty background opacity.
- Starship palette for new prompts.

Starship:

- `starship.toml` contains Catppuccin Latte, Frappe, Macchiato and Mocha palettes.
- `catppuccin-tiling-mode.sh` updates the active `palette = "catppuccin_<flavour>"` line whenever the theme changes.
- Existing prompts do not repaint; new prompts use the updated palette.

Yazi and lazygit stay Catppuccin-aligned and use the same visual family, but they are not currently live-rewritten per flavour.

## Borders

`scripts/jankyborders.sh` uses:

- active border: full-opacity current Catppuccin accent.
- inactive border: muted translucent surface colour.
- width: `4.0`.
- style: native rounded, HiDPI on.
- blacklist: Dock, Window Server, Control Center, Notification Center, SystemUIServer, Spotlight and loginwindow.
- apply path: every apply restarts the borders process cleanly to avoid stale border overlays for apps that have already closed.

This keeps focused windows visible without making unfocused windows disappear.

## Sounds

Script:

```sh
~/.config/scripts/aesthetic-sound.sh
```

Sounds are only used for aesthetic actions such as theme changes, reloads and toggles. Normal window switching and daily work stay silent. The script uses low-volume system sounds through `afplay` and can be disabled through the popup or command line.

Commands:

```sh
~/.config/scripts/aesthetic-sound.sh status
~/.config/scripts/aesthetic-sound.sh toggle
~/.config/scripts/aesthetic-sound.sh off
```

## Shelf

Script:

```sh
~/.config/scripts/shelf.sh
```

Folder:

```sh
~/.config/ricing/shelf
```

Commands:

```sh
~/.config/scripts/shelf.sh open
~/.config/scripts/shelf.sh list
~/.config/scripts/shelf.sh path
```

## AeroSpace


SwiftBar:

- plugin: `swiftbar/catppuccin-rice.1m.sh`.
- LaunchAgent: `swiftbar/com.kianconti.swiftbar.plist`.
- plugin link target: `~/Library/Application Support/SwiftBar/Plugins/catppuccin-rice.1m.sh`.

Layout philosophy:

- Default layout is `tiles` with automatic orientation.
- Halves and balanced quarters are preferred over constant thirds.
- Quarter layouts are shaped with explicit vertical/horizontal splits, movement, joins and balance commands.
- `Alt+q` is the quick helper for a three-window shape: one half plus two quarters.
- Apple Terminal is detected by bundle id and floated automatically; Kitty stays tiled.
- True always-on-top is not exposed by this AeroSpace build, so no always-on-top hack is installed.
- AeroSpace does not provide true drag-to-corner quarter snapping in this build.
- Smooth WM animation is limited by AeroSpace itself; the setup avoids fragile animation hacks.

Notable config:

- `exec-on-workspace-change` triggers SketchyBar workspace updates.
- `persistent-workspaces` keeps workspaces 1-9 addressable.
- Gaps reserve room for the top bar.
- System Settings and Finder utility dialogs float.

## Startup

LaunchAgent:

```sh
~/.config/ricing/com.kianconti.catppuccin-session.plist
~/Library/LaunchAgents/com.kianconti.catppuccin-session.plist
```

At login it checks:

```sh
~/.config/ricing/session_enabled
```

If the value is `1`, it starts the session. If the value is `0`, it keeps the ricing runtime off.

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
starship explain
```

Docs generated by ChatGPT Codex.
