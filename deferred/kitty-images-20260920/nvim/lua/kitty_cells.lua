-- Local installation bridge. The plugin directory is independently portable.
local root = vim.fn.stdpath("config") .. "/kitty-cells.nvim"
vim.opt.runtimepath:prepend(root)
return assert(loadfile(root .. "/lua/kitty_cells/init.lua"))()
