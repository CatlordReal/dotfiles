# kitty-cells.nvim

A small image API for Neovim inside Kitty. Render SVGs and raster images into
exact character-cell rectangles, including 1×1, 2×2, and 2×3.

The API measures the terminal's **physical pixel dimensions per cell**, then
composites artwork onto an exact transparent canvas. A square in a 10×20-pixel
cell becomes a 10×10-pixel square with five pixels of transparent padding above
and below. It is not stretched into a tall rectangle. Integer-pixel alignment
can differ from the mathematical center by at most half a pixel.

Images use [Kitty's Unicode placeholder protocol](https://sw.kovidgoyal.net/kitty/graphics-protocol/#unicode-placeholders).
Neovim draws ordinary cell-width placeholder text through extmarks; Kitty replaces
it with pixels. This lets normal redraw, scrolling, splits, and clipping move
the displayed image without separate screen-coordinate tracking.

## Requirements and installation

- Neovim 0.11+, `set termguicolors`, and Kitty 0.28+ on macOS or Linux.
- `python3`, ImageMagick 7 (`magick`), and `rsvg-convert` (librsvg).
- Run directly in Kitty. tmux, screen, GUI Neovim, and remote attached UIs are
  outside this version's supported transport.

On this machine the plugin is installed at `~/.config/nvim/kitty-cells.nvim`.
The new `lua/kitty_cells.lua` bridge and `plugin/kitty_cells.lua` loader expose
the API and commands. No existing configuration file was edited.

The plugin directory is portable. On another installation, copy it to
`~/.config/nvim/pack/local/start/kitty-cells.nvim`, or use a lazy.nvim entry:

```lua
{ dir = vim.fn.expand("~/path/to/kitty-cells.nvim"), opts = {} }
```

Use `:KittyCellsDemo` for the SVG alignment gallery, `:checkhealth kitty_cells`
for dependency/cell-size checks, and `:KittyCellsClear` to release images.

## First image

This creates a separate scratch buffer and reserves a single character:

```lua
local cells = require("kitty_cells")
local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(buf)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "[ ]" })

local icon = cells.new({
  path = "/absolute/path/icon.svg", -- PNG, JPEG, WebP, GIF, etc. also work
  cols = 1,
  rows = 1,
  fit = "contain",
  scale = 1,
  align_x = "center",
  align_y = "center",
})
icon:place({ buf = buf, row = 0, col = 1 })
```

`new()` returns immediately. Conversion runs asynchronously, with at most two
renderer processes at once. Placement can be requested before rendering finishes.

For 2×3, reserve three lines containing two spaces at the same display column,
then request `cols = 2, rows = 3`. `place()` never inserts or overwrites text.
It requires existing ASCII spaces in the reserved rectangle. Coordinates are
zero-based buffer rows and **byte columns**, not screen coordinates. All rows
must start at the same display column. Use `nowrap` in layout buffers for an
unbroken rectangle; wrapping and folding intentionally follow Neovim's text layout.

## Scaling and alignment

| Option | Behavior |
| --- | --- |
| `fit = "contain"` | Preserve aspect ratio; fit the entire source inside the box. Default. |
| `fit = "cover"` | Preserve aspect ratio; fill the box and clip overflow. |
| `fit = "fill"` | Stretch width and height independently to fill the box. |
| `fit = "none"` | Use the source's intrinsic pixel size. |
| `scale = 0.5` | Multiply the chosen mode's size by 0.5. Any positive finite value. |
| `align_x` | `"left"`, `"center"`, or `"right"`. Default: center. |
| `align_y` | `"top"`, `"center"`, or `"bottom"`. Default: center. |

Alignment applies after scaling, including oversized images. For example,
`fit = "none", scale = 2, align_x = "right", align_y = "bottom"` keeps the
bottom-right corner of native-size artwork doubled; any overflow is clipped
to the requested cell rectangle.

SVGs are rasterized at the requested output size using librsvg. Alignment is
relative to the SVG viewport, including any intentional whitespace inside its
viewBox. The API does not trim artwork or guess its optical center. Raster
formats use the first frame. Animated playback is not implemented.
SVG sizing accepts UTF-8 XML with absolute width/height units or a viewBox; CSS-only intrinsic
sizes are not supported. The root element must occur within the first 1 MiB of
decompressed data. SVG DTD/entity declarations are rejected.

## API for the next plugin

```lua
local image = cells.new({
  path = asset_path,
  cols = 2, rows = 3,
  on_ready = function(image)
    -- Also called after a successful refresh changes the rendered image.
    local lines = image:lines()
    -- lines[row] is a Neovim highlight-chunk list: { { text, highlight_group } }.
    -- Use these directly in your own virt_text / virt_lines layout.
  end,
  on_error = function(message, image)
    -- A conversion or upload failure. image.state == "error".
  end,
})

image:place({ buf = buffer, row = 4, col = 2, priority = 200 })
image:unplace() -- Remove the owned extmarks, retain the image texture.
image:refresh() -- Recheck cell pixels and source mtime; convert only if changed.
image:delete()  -- Remove owned extmarks and free this Kitty image ID; idempotent.
cells.refresh()
cells.clear()
```

`image.state`: `"loading"`, `"ready"`, `"error"`, or `"deleted"`.
`image.error` contains the last error. `image:lines()` returns `nil, reason`
until ready. Ready handles expose `image.cell_size` and `image.metadata`
(canvas, source, and placement pixel geometry).

`place()` manages one location per handle; calling it again moves that location.
Buffer extmarks follow edits, but your consumer still owns maintaining its
reserved rectangular layout when editing inside the rectangle. The same buffer
can appear in multiple splits. Low-level `lines()` consumers own their marks and
must remove them before calling `delete()`; `delete()` cannot remove marks that
another plugin created. Low-level consumers should also call `delete()` when
their view is destroyed. Handles placed with `place()` are released on buffer wipe.

Do not alter the placeholder foreground color: its RGB value encodes the image
ID. Use `hl_mode = "replace"` for your own extmarks. Each row includes explicit
row/column diacritics so clipping does not depend on neighboring cells.

Font or terminal size changes trigger a pixel-size refresh on `VimResized` and
`FocusGained`. Use `:KittyCellsRefresh` if the terminal does not emit a resize.
Theme changes restore the ID highlight groups. All image IDs owned by this API
are released on exit; unrelated terminal images are not deleted. Conversion
results are cached for this Neovim session in a temporary directory, removed on
normal exit. A crash may leave temporary files behind.

Terminal metrics use inherited TUI file descriptors, including Neovim children
without `/dev/tty`. Graphics writes reopen that terminal device independently so
Neovim's nonblocking descriptor flags do not drop image packets.

If your terminal does not expose pixel dimensions through `TIOCGWINSZ`, supply
the **physical** cell dimensions explicitly (not font points or logical pixels):

```lua
cells.setup({ cell_size = { width = 18, height = 38 } })
-- Or cell_size = function() return { width = ..., height = ... } end
```

Each dimension is limited by Kitty's 297-entry placeholder coordinate table and
the renderer's 16,384-pixel / 64-million-pixel canvas, decoded raster, and scaled-image limits. Tiny
scales that round below one pixel produce an explicit error. Conversion errors
call `on_error` or show a Neovim error notification; terminal packets use Kitty's
quiet mode, so acceptance by the terminal is not acknowledged. `ready` means
conversion and transmission completed, not a GPU screenshot verification.

## Validation

From this directory:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v
nvim --headless -u NONE -i NONE -l tests/test_api.lua
# On this machine, also verify the local loader and complete demo:
nvim --headless -u NONE -i NONE -l tests/test_install.lua
```

The tests exercise actual SVG/raster conversion and pixel geometry, real PTY cell
metrics, PNG protocol payloads and chunking, placeholder display widths, extmark
movement, cancellation, cleanup, invalid options, and resize/theme refresh.
The headless transport test captures packets instead of sending them to Kitty.
The interactive `:KittyCellsDemo` is the final display check inside a real Kitty
window; automated checks do not prove GPU rendering.
