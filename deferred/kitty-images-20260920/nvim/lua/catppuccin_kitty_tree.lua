local root = vim.fn.stdpath("config") .. "/catppuccin-kitty-tree.nvim"
vim.opt.runtimepath:prepend(root)
return assert(loadfile(root .. "/lua/catppuccin_kitty_tree/init.lua"))()
