# catppuccin-kitty-tree.nvim

Catppuccin's official VS Code SVG icons in **mini.files** and **Neo-tree**, using
the local `kitty-cells.nvim` image API. Icons default to a centered **1×1 cell**.
The square artwork preserves its aspect ratio inside the terminal's tall cells.

## Installed integration

The local loader is `~/.config/nvim/plugin/catppuccin_kitty_tree.lua`. The only
existing configuration change adds an icon component to Neo-tree's filesystem
configuration. Your `<leader>nt` toggle, `<leader>nT` tree switch, navigation,
filtering, file operations, git indicators, and diagnostic indicators keep their
existing configuration. mini.files uses its existing prefix without a setup change.

The plugin overlays images at native icon positions. **It does not write
placeholder text or asset paths into editable tree buffers.** Disabling it reveals
the original icons immediately. Theme changes do not refresh/discard pending
mini.files filesystem edits.

## Commands

```vim
:CatppuccinTreeIconsToggle
:CatppuccinTreeIconsEnable
:CatppuccinTreeIconsDisable
:CatppuccinTreeIconsRefresh
```

Closing a tree removes its overlays and releases unused image textures. Newly
added or removed files follow the tree's normal filesystem refresh behavior.
`Refresh` reloads the asset definitions and retries failed image conversions.

On an already-running Neovim session, the new mini.files hooks can be loaded with
`:lua require('catppuccin_kitty_tree').setup()`. Restart Neovim to load the new
Neo-tree component through your updated configuration.

## Palette and assets

The assets are the official
[Catppuccin VS Code icon extension](https://github.com/catppuccin/vscode-icons),
v1.26.0, already installed at
`~/.config/nvim/icons/catppuccin/vscode-icons/dist`. That release contains distinct
Latte, Frappé, Macchiato, and Mocha SVG sets. Their original license remains in
the existing asset repository.

The active `catppuccin-<flavour>` colorscheme selects the matching set on every
`ColorScheme` event. If another colorscheme is active, the last configured
`vim.g.catppuccin_flavour` is used; otherwise background brightness chooses Latte
or Mocha. This follows Neovim's flavour, not the separate VS Code application's
current setting.

Associations come from the extension's `theme.json`: filenames, longest matching
compound extensions (such as `spec.ts`), language IDs when supplied, named folders,
expanded folders, and root folders. Unknown types use the extension's fallback
icons. Replacing/updating the existing asset pack and running `Refresh` picks up
its new definitions. There is no automatic network updater.

## Options and reusable API

```lua
require('catppuccin_kitty_tree').setup({
  enabled = true,
  cols = 1,             -- 1 or 2, within the native icon + padding slot
  fit = 'contain',       -- contain, cover, fill, none
  scale = 1,
  align_x = 'center',    -- left, center, right
  align_y = 'center',    -- top, center, bottom
  assets = vim.fn.stdpath('config') .. '/icons/catppuccin/vscode-icons/dist',
})
```

An icon is skipped if a custom prefix provides less room than the requested
column count. In another configuration, use the plugin directory on runtimepath,
install `kitty-cells.nvim`, and set:

```lua
require('neo-tree').setup({
  filesystem = {
    components = {
      icon = require('catppuccin_kitty_tree').neo_icon,
    },
  },
})
```

Lua controls: `enable()`, `disable()`, `toggle()`, `refresh()`, `flavour()`,
and `status()` (enabled, availability, flavour, textures, and placements).
The underlying image API still provides `new()`, `place()`, `unplace()`, and
`delete()` for independent consumers; use the tree commands for tree-owned icons.

## Requirements and tests

Neovim 0.11+, Kitty 0.28+, true color, Python 3, ImageMagick 7, and librsvg.
Run directly in Kitty. Unsupported terminals retain native icons; image failures
also retain them and report a warning. Animation and multiplexer transport are
outside this version's scope.

From this plugin directory, using the installed tree plugins:

```sh
nvim --headless -u NONE -i NONE -l tests/test_atlas.lua
nvim --headless -u NONE -i NONE -l tests/test_integration.lua
```

The integration test opens both actual tree plugins against temporary files,
captures graphics packets, and checks palette switching, pending edit preservation,
enable/disable, folder expansion, file add/remove, and texture cleanup. Packet
tests and native Kitty runs are distinct from visual screenshot verification.
