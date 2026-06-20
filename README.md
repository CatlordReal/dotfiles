# Dotfiles

These are my macOS dotfiles. The repo mirrors the configs I actually use, with a small sync helper instead of a dotfile framework.

The main setup includes:

- Neovim as the editor and theme control centre.
- Kitty as the terminal.
- AeroSpace for tiling.
- SketchyBar as the top bar.
- Karabiner for keyboard remaps.
- JankyBorders for themed focus borders.
- Starship, Yazi, lazygit, zoxide, eza, bat, fzf and delta for terminal workflow.

Detailed implementation notes for the ricing setup live in:

- [docs/ricing-technical.md](docs/ricing-technical.md)

## Layout

- `aerospace/`: window manager config.
- `borders/`: JankyBorders LaunchAgent.
- `karabiner/`: keyboard rules.
- `kitty/`: Kitty config and active theme.
- `lazygit/`: lazygit config.
- `nvim/`: Neovim config.
- `ricing/`: startup helper plist and notes.
- `scripts/`: session and theme helper scripts.
- `sketchybar/`: SketchyBar config.
- `starship.toml`: prompt config.
- `svim/`: SketchyVim config.
- `yazi/`: Yazi config.
- `zsh/`: shell integration.
- `sync-config-to-dotfiles`: sync live configs back into this repo.

## Install

Install the main tools:

```sh
brew install aerospace sketchybar borders nowplaying-cli brightness starship yazi lazygit git-delta zoxide eza bat fzf btop tmux
brew install --cask kitty karabiner-elements
```

Restore the configs:

```sh
mkdir -p ~/.config
cp -R ~/dotfiles/aerospace ~/.config/
cp -R ~/dotfiles/borders ~/.config/
cp -R ~/dotfiles/karabiner ~/.config/
cp -R ~/dotfiles/kitty ~/.config/
cp -R ~/dotfiles/lazygit ~/.config/
cp -R ~/dotfiles/nvim ~/.config/
cp -R ~/dotfiles/ricing ~/.config/
cp -R ~/dotfiles/scripts ~/.config/
cp -R ~/dotfiles/sketchybar ~/.config/
cp -R ~/dotfiles/svim ~/.config/
cp -R ~/dotfiles/yazi ~/.config/
cp -R ~/dotfiles/zsh ~/.config/
cp -R ~/dotfiles/wallpapers ~/.config/
cp ~/dotfiles/starship.toml ~/.config/starship.toml
```

Add the shell hook if it is missing:

```sh
printf '\n# Catppuccin ricing tools\n[[ -r "$HOME/.config/zsh/ricing.zsh" ]] && source "$HOME/.config/zsh/ricing.zsh"\n' >> ~/.zshrc
```

## Sync Changes

Before committing config changes, sync live files back into the repo:

```sh
~/dotfiles/sync-config-to-dotfiles --include aerospace,sketchybar,karabiner,kitty,nvim,scripts,yazi,lazygit,zsh,wallpapers
cp -p ~/.config/starship.toml ~/dotfiles/starship.toml
cp -p ~/.zshrc ~/dotfiles/zshrc
```

If the sync helper marks old repo-only scripts as deleted and I did not intend to remove them:

```sh
git -C ~/dotfiles restore scripts/USAGE.md scripts/ctd scripts/kitty-wallpaper scripts/newcpp scripts/tsaver
```

Commit:

```sh
git -C ~/dotfiles status -sb
git -C ~/dotfiles diff --stat
git -C ~/dotfiles add <files>
git -C ~/dotfiles commit -m "Describe the change"
git -C ~/dotfiles push
```

## Ricing Session

Start the full Catppuccin tiling setup:

```sh
~/.config/scripts/catppuccin-session.sh on mocha
```

Stop it:

```sh
~/.config/scripts/catppuccin-session.sh off
```

Toggle it:

```sh
~/.config/scripts/catppuccin-session.sh toggle
```

Check status:

```sh
~/.config/scripts/catppuccin-session.sh status
```

The session starts or stops AeroSpace, SketchyBar, JankyBorders, SketchyVim preference, wallpaper, desktop icon visibility, theme sync and Kitty opacity.

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
- `Alt+Shift+-` / `Alt+Shift+=`: larger smart resize steps.
- `Alt+f`: fullscreen focused window.
- `Alt+Shift+Space`: toggle floating/tiling.
- `Alt+/`: toggle tile orientation.
- `Alt+,`: accordion layout.
- `Alt+v`: split vertical.
- `Alt+b`: split horizontal.
- `Alt+Shift+b`: balance sizes.
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
- `v`: split vertical.
- `s`: split horizontal.
- `h/j/k/l`: resize width/height.
- `Alt+Shift+h/j/k/l`: join with neighbour in that direction.
- `Backspace`: close all windows except current.

## Karabiner And Hyper

Caps Lock is scoped to Kitty only:

- Tap Caps in Kitty: Escape.
- Hold Caps in Kitty: Hyper (`Control+Option+Command+Shift`).
- Outside Kitty: normal Caps Lock.

Hyper shortcuts:

- `Hyper+Enter`: open Kitty.
- `Hyper+M`: open Music.
- `Hyper+F`: open Finder.
- `Hyper+R`: reload AeroSpace, SketchyBar and JankyBorders.
- `Hyper+T`: toggle the full Catppuccin tiling session.
- `Hyper+1` through `Hyper+9`: switch AeroSpace workspace.
- `Hyper+h/j/k/l`: focus left/down/up/right via AeroSpace.
- `Hyper+Arrow keys`: move focused window left/down/up/right via AeroSpace.

Fallback toggle:

- `Control+Option+Command+T`: toggle the full Catppuccin tiling session.

## SketchyBar Usage

- Workspace items switch AeroSpace workspaces.
- Dragging an app/file onto a workspace item moves the focused window there when supported.
- Apple Music artwork/title/artist appears while playing.
- Clicking Apple Music artwork opens popup controls.
- Scroll over volume to adjust volume.
- Click volume to open output devices when `SwitchAudioSource` is available.
- Click network to open network details.
- Scroll over brightness to adjust in 5% steps.
- Click brightness to open Displays settings.
- Click weather to open `wttr.in`.

Weather location can be set before starting SketchyBar:

```sh
export SKETCHYBAR_WEATHER_LOCATION=London
```

## Terminal Commands

- `lg`: lazygit.
- `yy`: open Yazi and `cd` to the final directory when it exits.
- `ls`: eza with icons.
- `ll`: long eza listing with Git info.
- `la`: all files with eza.
- `lt`: shallow eza tree.
- `cat`: bat without paging.

Kitty opacity:

```sh
~/.config/scripts/kitty-opacity.sh 70
~/.config/scripts/kitty-opacity.sh 0.70
~/.config/scripts/kitty-opacity.sh 70%
```

## Manual Service Commands

Reload SketchyBar:

```sh
sketchybar --reload
```

Start or reload AeroSpace:

```sh
open -a AeroSpace
aerospace reload-config
```

Stop AeroSpace:

```sh
osascript -e 'quit app "AeroSpace"'
```

Toggle borders:

```sh
~/.config/scripts/jankyborders.sh toggle
```

Undo the ricing session:

```sh
~/.config/scripts/catppuccin-session.sh off
launchctl bootout "gui/$(id -u)/com.kianconti.sketchybar" 2>/dev/null
~/.config/scripts/jankyborders.sh off
~/.config/scripts/sketchyvim-toggle.sh off
osascript -e 'quit app "AeroSpace"'
```

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
yazi --version
lazygit --version
delta --version
starship explain
```
