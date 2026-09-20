# Neovim controls

The leader key is Space.

## Theme rotation

Open `<leader>cc` (or `:ColorTheme`) and choose **Catppuccin rotation**. The setting survives restarts and checks the local clock every 30 seconds, on focus, and after resume. Neovim and Kitty colours stay together through the existing Kitty theme sync. No desktop settings change.

| Local time | Theme |
| --- | --- |
| 07:00–15:59 | Latte |
| 16:00–18:59 | Frappé |
| 19:00–21:59 | Macchiato |
| 22:00–06:59 | Mocha |

Choose **Rotation times** in the picker, or run `:ColorThemeRotation times`, to change the four start times. Values must use `HH:MM` and increase from Latte to Mocha. This is a clock schedule, not a location-based astronomical schedule.

Choosing any fixed theme stops rotation. `:ColorThemeRotation off` keeps the current theme; `:ColorThemeRotation on` and `:ColorThemeSet catppuccin-rotation` enable rotation. Changes use the existing immediate colourscheme refresh without added motion. State lives in Neovim's state directory (`theme-rotation.json`). Rotation runs while Neovim is open; the next launch catches up after it was closed.

## File managers

`<leader>nt` opens the selected file manager and `<leader>nT` switches between mini.files and Neo-tree. Both use upstream stable releases and ordinary font icons. Kitty image rendering and image tree overlays are saved separately under `deferred/kitty-images-20260920` for later work.

The lockfile records mini.files v0.18.0 and Neo-tree 3.42.0. `:Lazy restore` installs the recorded versions; `:Lazy update` can select future stable releases because both use `version = "*"`.

## C++ and dotfiles

| Keys / command | Action |
| --- | --- |
| `<leader>rf` or `<leader>rr` | Save, compile and run the current C++ file |
| `<leader>rp` | Build and run the configured C++ project from a C++ buffer |
| `<leader>rP` / `:CppRunProject` | Open the C++ project runner from any buffer |
| `<leader>rs` / `:CppRunSettings` | Set compiler, flags, arguments and project preferences |
| `<leader>uu` / `:DotfilesUpdate` | Preview and update installed dotfiles from GitHub |
| `<leader>uU` / `:DotfilesUpdateCheck` | Check for changes without applying them |
| `:DotfilesUpdateAll` | Include existing shell dotfiles in the update preview |

Other languages keep their existing runner. See [C++ runner](cpp-runner.md) and [dotfiles updater](dotfiles-update.md) for configuration and recovery details. Dotfiles updates do not run downloaded install scripts or update plugin checkouts; restart Neovim after applying config, then use `:Lazy restore` when you want the recorded plugin versions.
