local root = vim.fn.getcwd()
vim.opt.rtp:prepend(root)
vim.opt.rtp:prepend(vim.fn.fnamemodify(root, ":h") .. "/kitty-cells.nvim")
for _, plugin in ipairs({ "mini.files", "mini.icons", "neo-tree.nvim", "plenary.nvim", "nui.nvim", "nvim-web-devicons" }) do
  vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/" .. plugin)
end
vim.o.termguicolors = true
vim.g.colors_name = "catppuccin-mocha"
local writes, notifications = {}, {}
vim.notify = function(text, level) if level and level >= vim.log.levels.WARN then notifications[#notifications+1] = text end end
require("kitty_cells").setup({ cell_size = { width = 12, height = 24 }, writer = function(s) writes[#writes+1] = s end })
local icons = require("catppuccin_kitty_tree").setup({ test_mode = true })
require("mini.icons").setup()
local mini = require("mini.files")
mini.setup({ windows = { preview = false }, mappings = { close = "q" } })
require("neo-tree").setup({ filesystem = { components = { icon = icons.neo_icon }, filtered_items = { visible = true } },
  enable_git_status = false, enable_diagnostics = false })
local fixture = vim.fn.tempname() .. "-icon-tree"
vim.fn.mkdir(fixture .. "/src", "p")
vim.fn.mkdir(fixture .. "/tests", "p")
fixture = assert(vim.uv.fs_realpath(fixture))
vim.fn.writefile({ "export default 1" }, fixture .. "/src/main.ts")
for _, name in ipairs({ "package.json", "README.md", "main.py", "example.spec.ts", "unknown.xyzxyz" }) do
  vim.fn.writefile({ "fixture" }, fixture .. "/" .. name)
end
local function wait_for(predicate, label)
  assert(vim.wait(15000, predicate, 20), label .. ": " .. vim.inspect(icons.status()) .. " " .. vim.inspect(notifications))
end

mini.open(fixture, false)
wait_for(function() return icons.status().placements == 7 and icons.status().pending == 0 end, "mini icons")
local buf = vim.api.nvim_get_current_buf()
local original = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
assert(not table.concat(original):find(vim.fn.nr2char(0x10EEEE), 1, true), "Placeholders must not enter editable filenames")
icons.disable()
assert(icons.status().placements == 0 and icons.status().ready == 0)
assert(vim.deep_equal(original, vim.api.nvim_buf_get_lines(buf, 0, -1, false)), "Disabling must preserve file operations")
icons.enable()
wait_for(function() return icons.status().placements == 7 and icons.status().pending == 0 end, "mini re-enable")

-- Theme swaps remove/recreate only visual marks; pending file edits survive.
local edited = original[#original] .. "-renamed"
vim.api.nvim_buf_set_lines(buf, #original - 1, #original, false, { edited })
for _, flavour in ipairs({ "latte", "frappe", "macchiato", "mocha" }) do
  vim.g.colors_name = "catppuccin-" .. flavour
  vim.api.nvim_exec_autocmds("ColorScheme", { pattern = vim.g.colors_name })
  wait_for(function() return icons.status().placements == 7 and icons.status().pending == 0 end, "flavour " .. flavour)
  assert(icons.status().flavour == flavour)
  assert(vim.api.nvim_buf_get_lines(buf, #original-1, #original, false)[1] == edited, "Theme change discarded pending edit")
end
vim.api.nvim_buf_set_lines(buf, 0, -1, false, original)
vim.bo[buf].modified = false
mini.close()
wait_for(function() return icons.status().placements == 0 and icons.status().ready == 0 end, "mini close")

require("neo-tree.command").execute({ action = "show", source = "filesystem", position = "left", dir = fixture })
wait_for(function() return icons.status().placements >= 8 and icons.status().pending == 0 end, "neo icons")
local state = require("neo-tree.sources.manager").get_state("filesystem")
local neo_buf = state.bufnr
local neo_text = vim.api.nvim_buf_get_lines(neo_buf, 0, -1, false)
assert(not table.concat(neo_text):find(vim.fn.nr2char(0x10EEEE), 1, true))
local node = state.tree:get_node(fixture .. "/src")
assert(node)
require("neo-tree.sources.filesystem").toggle_directory(state, node)
wait_for(function() return icons.status().placements >= 9 and icons.status().pending == 0 end, "expanded directory")
for _, flavour in ipairs({ "latte", "frappe", "macchiato", "mocha" }) do
  vim.g.colors_name = "catppuccin-" .. flavour
  vim.api.nvim_exec_autocmds("ColorScheme", { pattern = vim.g.colors_name })
  wait_for(function() return icons.status().placements == 9 and icons.status().pending == 0 end, "neo flavour " .. flavour)
end
icons.disable()
assert(icons.status().placements == 0 and icons.status().ready == 0)
icons.enable()
wait_for(function() return icons.status().placements >= 9 and icons.status().pending == 0 end, "neo re-enable")
vim.fn.writefile({ "new" }, fixture .. "/added.lua")
require("neo-tree.sources.manager").refresh("filesystem")
wait_for(function() return state.tree:get_node(fixture .. "/added.lua") ~= nil and icons.status().placements == 10 and icons.status().pending == 0 end, "file add")
vim.fn.delete(fixture .. "/added.lua")
require("neo-tree.sources.manager").refresh("filesystem")
wait_for(function() return state.tree:get_node(fixture .. "/added.lua") == nil and icons.status().placements == 9 and icons.status().pending == 0 end, "file remove")
require("neo-tree.command").execute({ action = "close", source = "filesystem" })
wait_for(function() return icons.status().placements == 0 and icons.status().ready == 0 end, "neo close")
assert(#notifications == 0, vim.inspect(notifications))
vim.fn.delete(fixture, "rf")
print("TREE_PASS: both real trees, all flavours, toggle, pending edits, expand, add/remove, cleanup")
vim.cmd("qa!")
