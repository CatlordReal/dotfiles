# Deferred Kitty image experiments

Saved on 2026-09-20 before returning the active file managers to upstream stable code and ordinary font icons. Nothing in this directory is loaded by Neovim.

- `nvim/kitty-cells.nvim`: image renderer, examples and tests.
- `nvim/catppuccin-kitty-tree.nvim`: experimental mini.files/Neo-tree image overlays and earlier test evidence.
- `nvim/lua` and `nvim/plugin`: the local runtime bridges and startup hooks.
- `nvim/init.lua`: the original configuration including the Neo-tree icon wrapper.

The matching local archive is `~/.config/deferred/kitty-images-20260920`. Existing icon assets remain at `~/.config/nvim/icons/catppuccin/vscode-icons`; repository source assets are retained under `nvim/icons`. Generated assets can be rebuilt following the archived plugin README.

Earlier evidence is historical, not a claim of current visual correctness. Before resuming, recheck terminal geometry, redraw/scroll behavior and real screenshots. Restore only the renderer directories, bridges, hooks and Neo-tree `components.icon` wrapper after review; do not replace the current configuration wholesale with this older `init.lua`.
