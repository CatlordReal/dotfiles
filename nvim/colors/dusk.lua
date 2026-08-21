local c = {
  bg = "#20233B", sidebar = "#191C30", surface = "#303653", elevated = "#414967",
  fg = "#E7E9FF", muted = "#AEB4D6", accent = "#B8A1FF", warm = "#7DCFFF",
  positive = "#95D5B2", orange = "#F6C177", red = "#EB6F92",
}

vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then vim.cmd("syntax reset") end
vim.o.termguicolors = true
vim.o.background = "dark"
vim.g.colors_name = "dusk"

local function hi(group, opts) vim.api.nvim_set_hl(0, group, opts) end
hi("Normal", { fg = c.fg, bg = c.bg })
hi("NormalFloat", { fg = c.fg, bg = c.surface })
hi("Comment", { fg = c.muted, italic = true })
hi("Constant", { fg = c.orange })
hi("String", { fg = c.positive })
hi("Character", { fg = c.positive })
hi("Number", { fg = c.orange })
hi("Boolean", { fg = c.accent })
hi("Identifier", { fg = c.warm })
hi("Function", { fg = c.accent })
hi("Statement", { fg = c.accent })
hi("Keyword", { fg = c.accent, italic = true })
hi("Operator", { fg = c.warm })
hi("PreProc", { fg = c.orange })
hi("Type", { fg = c.warm })
hi("Special", { fg = c.accent })
hi("Underlined", { fg = c.warm, underline = true })
hi("Error", { fg = c.red, bold = true })
hi("Todo", { fg = c.bg, bg = c.orange, bold = true })
hi("LineNr", { fg = c.muted, bg = c.bg })
hi("CursorLineNr", { fg = c.orange, bg = c.elevated, bold = true })
hi("CursorLine", { bg = c.surface })
hi("Visual", { bg = c.elevated })
hi("Search", { fg = c.bg, bg = c.orange, bold = true })
hi("IncSearch", { fg = c.bg, bg = c.accent, bold = true })
hi("Pmenu", { fg = c.fg, bg = c.surface })
hi("PmenuSel", { fg = c.bg, bg = c.accent, bold = true })
hi("StatusLine", { fg = c.fg, bg = c.elevated, bold = true })
hi("StatusLineNC", { fg = c.muted, bg = c.surface })
hi("WinSeparator", { fg = c.elevated, bg = c.bg })
hi("DiagnosticError", { fg = c.red })
hi("DiagnosticWarn", { fg = c.orange })
hi("DiagnosticInfo", { fg = c.warm })
hi("DiagnosticHint", { fg = c.positive })
hi("DiagnosticOk", { fg = c.positive })
hi("GitSignsAdd", { fg = c.positive })
hi("GitSignsChange", { fg = c.orange })
hi("GitSignsDelete", { fg = c.red })
hi("NeoTreeNormal", { fg = c.fg, bg = c.sidebar })
hi("NeoTreeNormalNC", { fg = c.muted, bg = c.sidebar })
hi("NeoTreeDirectoryName", { fg = c.warm })
hi("NeoTreeDirectoryIcon", { fg = c.accent })
hi("NeoTreeFileNameOpened", { fg = c.orange, bold = true })
hi("NeoTreeRootName", { fg = c.accent, bold = true })
hi("NeoTreeGitAdded", { fg = c.positive })
hi("NeoTreeGitModified", { fg = c.orange })
hi("NeoTreeGitDeleted", { fg = c.red })

vim.g.terminal_color_0 = c.sidebar
vim.g.terminal_color_1 = c.red
vim.g.terminal_color_2 = c.positive
vim.g.terminal_color_3 = c.orange
vim.g.terminal_color_4 = c.warm
vim.g.terminal_color_5 = c.accent
vim.g.terminal_color_6 = c.warm
vim.g.terminal_color_7 = c.fg
vim.g.terminal_color_8 = c.muted
vim.g.terminal_color_9 = c.red
vim.g.terminal_color_10 = c.positive
vim.g.terminal_color_11 = c.orange
vim.g.terminal_color_12 = c.warm
vim.g.terminal_color_13 = c.accent
vim.g.terminal_color_14 = c.warm
vim.g.terminal_color_15 = c.fg
