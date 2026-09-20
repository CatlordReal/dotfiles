local M = {}
function M.check()
  vim.health.start("kitty-cells.nvim")
  if vim.fn.has("nvim-0.11") == 1 then vim.health.ok("Neovim 0.11+")
  else vim.health.error("Neovim 0.11+ required") end
  for _, executable in ipairs({ "python3", "magick", "rsvg-convert" }) do
    if vim.fn.executable(executable) == 1 then vim.health.ok(executable .. " found")
    else vim.health.error(executable .. " missing") end
  end
  if vim.env.KITTY_WINDOW_ID or vim.env.TERM == "xterm-kitty" then vim.health.ok("Kitty environment detected (requires 0.28+)")
  else vim.health.warn("Run Neovim directly inside Kitty 0.28+") end
  if vim.env.TMUX or vim.env.STY then vim.health.error("Multiplexer transport is not supported") end
  if vim.o.termguicolors then vim.health.ok("True color enabled") else vim.health.error("Enable termguicolors") end
  local size, err = require("kitty_cells.terminal").cell_size()
  if size then vim.health.ok(("Cell pixels: %d x %d"):format(size.width, size.height))
  else vim.health.warn(err) end
end
return M
