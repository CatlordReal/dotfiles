local config = vim.fn.getcwd() .. "/nvim"
vim.opt.rtp:prepend(config)
local writing = require("writing_tools")

local values = writing._test.count({ "One two.", "", "Three." })
assert(values.words == 3)
assert(values.paragraphs == 2)
assert(values.lines == 3)
assert(values.characters == 16)

local buffer = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(buffer)
vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "alpha beta", "", "gamma" })
writing.setup({ keymaps = false })
assert(vim.fn.exists(":WritingCount") == 2)
vim.cmd("setfiletype markdown")
assert(vim.wo.spell)
assert(vim.bo.spelllang == "en_gb")
local selected = writing.count_range(1, 1)
assert(selected.words == 2 and selected.lines == 1)
local select = vim.ui.select
vim.ui.select = function(items, options, callback)
  assert(options.prompt == "Selected lines count")
  assert(options.format_item(items[2]) == "Words: 2")
  callback(items[2])
end
writing.count_command({ range = 1, line1 = 1, line2 = 1 })
vim.ui.select = select
local existing = vim.api.nvim_create_buf(false, true)
vim.bo[existing].filetype = "text"
writing.setup({ keymaps = false })
vim.api.nvim_buf_call(existing, function() assert(vim.wo.spell) end)
print("writing_tools: ok")
