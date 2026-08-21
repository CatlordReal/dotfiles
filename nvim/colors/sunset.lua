local c = {
  bg = "#2A1F2D", sidebar = "#211923", surface = "#443044", elevated = "#5A3C50",
  fg = "#FFE9D6", muted = "#D4B3B1", accent = "#FF8B6A", warm = "#F6C177",
  positive = "#9CCF9D", purple = "#C4A7E7", cyan = "#7DCFFF", red = "#EB6F92",
}

vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then vim.cmd("syntax reset") end
vim.o.termguicolors = true
vim.o.background = "dark"
vim.g.colors_name = "sunset"

local function hi(group, opts) vim.api.nvim_set_hl(0, group, opts) end
hi("Normal", { fg = c.fg, bg = c.bg })
hi("NormalFloat", { fg = c.fg, bg = c.surface })
hi("Comment", { fg = c.muted, italic = true })
hi("Constant", { fg = c.warm })
hi("String", { fg = c.positive })
hi("Character", { fg = c.positive })
hi("Number", { fg = c.warm })
hi("Boolean", { fg = c.purple })
hi("Identifier", { fg = c.cyan })
hi("Function", { fg = c.accent })
hi("Statement", { fg = c.purple })
hi("Keyword", { fg = c.purple, italic = true })
hi("Operator", { fg = c.accent })
hi("PreProc", { fg = c.warm })
hi("Type", { fg = c.cyan })
hi("Special", { fg = c.accent })
hi("Underlined", { fg = c.cyan, underline = true })
hi("Error", { fg = c.red, bold = true })
hi("Todo", { fg = c.bg, bg = c.warm, bold = true })
hi("LineNr", { fg = c.muted, bg = c.bg })
hi("CursorLineNr", { fg = c.warm, bg = c.elevated, bold = true })
hi("CursorLine", { bg = c.surface })
hi("Visual", { bg = c.elevated })
hi("Search", { fg = c.bg, bg = c.warm, bold = true })
hi("IncSearch", { fg = c.bg, bg = c.accent, bold = true })
hi("Pmenu", { fg = c.fg, bg = c.surface })
hi("PmenuSel", { fg = c.bg, bg = c.accent, bold = true })
hi("StatusLine", { fg = c.fg, bg = c.elevated, bold = true })
hi("StatusLineNC", { fg = c.muted, bg = c.surface })
hi("WinSeparator", { fg = c.elevated, bg = c.bg })
hi("DiagnosticError", { fg = c.red })
hi("DiagnosticWarn", { fg = c.warm })
hi("DiagnosticInfo", { fg = c.cyan })
hi("DiagnosticHint", { fg = c.positive })
hi("DiagnosticOk", { fg = c.positive })
hi("GitSignsAdd", { fg = c.positive })
hi("GitSignsChange", { fg = c.warm })
hi("GitSignsDelete", { fg = c.red })
hi("NeoTreeNormal", { fg = c.fg, bg = c.sidebar })
hi("NeoTreeNormalNC", { fg = c.muted, bg = c.sidebar })
hi("NeoTreeDirectoryName", { fg = c.cyan })
hi("NeoTreeDirectoryIcon", { fg = c.accent })
hi("NeoTreeFileNameOpened", { fg = c.warm, bold = true })
hi("NeoTreeRootName", { fg = c.purple, bold = true })
hi("NeoTreeGitAdded", { fg = c.positive })
hi("NeoTreeGitModified", { fg = c.warm })
hi("NeoTreeGitDeleted", { fg = c.red })

vim.g.terminal_color_0 = c.sidebar
vim.g.terminal_color_1 = c.red
vim.g.terminal_color_2 = c.positive
vim.g.terminal_color_3 = c.warm
vim.g.terminal_color_4 = c.cyan
vim.g.terminal_color_5 = c.purple
vim.g.terminal_color_6 = c.cyan
vim.g.terminal_color_7 = c.fg
vim.g.terminal_color_8 = c.muted
vim.g.terminal_color_9 = c.red
vim.g.terminal_color_10 = c.positive
vim.g.terminal_color_11 = c.warm
vim.g.terminal_color_12 = c.accent
vim.g.terminal_color_13 = c.purple
vim.g.terminal_color_14 = c.cyan
vim.g.terminal_color_15 = c.fg
