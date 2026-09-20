local M = {}

function M.open()
  local cells = require("kitty_cells")
  local root = debug.getinfo(1, "S").source:sub(2):match("^(.*)/lua/kitty_cells/demo.lua$")
  local path = root .. "/examples/square.svg"
  vim.cmd("tabnew")
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype, vim.bo[buf].bufhidden, vim.bo[buf].swapfile = "nofile", "wipe", false
  vim.api.nvim_buf_set_name(buf, "kitty-cells://demo/" .. buf)
  vim.wo.wrap, vim.wo.number, vim.wo.relativenumber = false, false, false
  vim.wo.signcolumn, vim.wo.cursorline = "no", false
  local lines = {
    "KITTY CELLS  /  SVG + raster foundation",
    "",
    "Each bracket encloses exactly cols x rows reserved cells.",
    "Square artwork keeps its shape in tall terminal cells.",
    "",
  }
  local examples = {
    { "1x1 centered", 1, 1, {} },
    { "2x2 centered", 2, 2, {} },
    { "2x3 centered", 2, 3, {} },
    { "4x3 contain, scale 0.5, top-left", 4, 3, { scale = 0.5, align_x = "left", align_y = "top" } },
    { "4x3 contain, scale 0.5, bottom-right", 4, 3, { scale = 0.5, align_x = "right", align_y = "bottom" } },
    { "4x2 cover (clipped)", 4, 2, { fit = "cover" } },
    { "4x2 native size, centered", 4, 2, { fit = "none" } },
    { "4x2 fill (stretched)", 4, 2, { fit = "fill" } },
    { "2x2 PNG raster, centered", 2, 2, { path = root .. "/examples/checker.png" } },
  }
  local placements = {}
  for _, example in ipairs(examples) do
    lines[#lines + 1] = example[1]
    placements[#placements + 1] = { row = #lines, cols = example[2], rows = example[3], options = example[4] }
    for _ = 1, example[3] do lines[#lines + 1] = "  [" .. string.rep(" ", example[2]) .. "]" end
    lines[#lines + 1] = ""
  end
  lines[#lines + 1] = "q: close demo   r: refresh pixel sizes   scroll: images follow text"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  for _, placement in ipairs(placements) do
    local opts = vim.tbl_extend("force", {
      path = path, cols = placement.cols, rows = placement.rows,
    }, placement.options)
    cells.new(opts):place({ buf = buf, row = placement.row, col = 3 })
  end
  vim.bo[buf].modifiable = false
  vim.keymap.set("n", "q", "<cmd>bwipeout<cr>", { buffer = buf, silent = true })
  vim.keymap.set("n", "r", cells.refresh, { buffer = buf, silent = true })
end

return M
