if vim.g.loaded_kitty_cells then return end
vim.g.loaded_kitty_cells = true
require("kitty_cells").setup()
