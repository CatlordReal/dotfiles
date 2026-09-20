-- Exercise the installed bridge and command loader without loading user init.lua.
local root = vim.fn.getcwd()
vim.opt.runtimepath:prepend(vim.fn.fnamemodify(root, ":h"))
vim.o.termguicolors = true
local cells = require("kitty_cells")
cells.setup({ cell_size = { width = 10, height = 20 }, writer = function() end })
vim.cmd("runtime plugin/kitty_cells.lua")
assert(vim.fn.exists(":KittyCellsDemo") == 2)
assert(vim.fn.exists(":KittyCellsClear") == 2)
assert(vim.fn.exists(":KittyCellsRefresh") == 2)
local errors = {}
local notify = vim.notify
vim.notify = function(message, level)
  if level == vim.log.levels.ERROR then errors[#errors + 1] = message end
end
vim.cmd("KittyCellsDemo")
local buf = vim.api.nvim_get_current_buf()
assert(vim.bo[buf].buftype == "nofile" and not vim.bo[buf].modifiable)
assert(vim.wait(10000, function()
  local marks = vim.api.nvim_buf_get_extmarks(buf, cells.namespace, 0, -1, { details = true })
  local count = 0
  for _, mark in ipairs(marks) do if mark[4].virt_text then count = count + 1 end end
  return count == 20
end, 10), "Demo images did not finish: " .. vim.inspect(errors))
assert(#errors == 0, vim.inspect(errors))
vim.cmd("bwipeout!")
vim.notify = notify
print("PASS: local installation bridge, commands, full SVG/PNG demo, buffer cleanup")
vim.cmd("qa!")
