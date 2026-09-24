local script = debug.getinfo(1, "S").source:sub(2)
local root = vim.fn.fnamemodify(script, ":h:h")
vim.opt.rtp:prepend(root .. "/nvim")

local clock = 0
local state_path = vim.fn.tempname() .. "/project-stats.json"
local project = vim.fn.tempname()
vim.fn.mkdir(project, "p")
project = vim.fs.normalize(project)
local stats = require("project_stats")
stats.setup({
  keymaps = false,
  timer = false,
  state_path = state_path,
  now = function() return clock end,
  root_resolver = function() return project end,
})

local first = vim.api.nvim_create_buf(true, false)
local second = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(first, project .. "/first.lua")
vim.api.nvim_buf_set_name(second, project .. "/second.lua")
vim.api.nvim_set_current_buf(first)
stats.start()
clock = 5 * 1000000000
stats.tick()
stats.record_char(first, "é")
clock = 10 * 1000000000
stats.activate(second)
clock = 16 * 1000000000
stats.tick()
local value = stats.summary(second)
local first_value = stats.summary(first)
assert(value.project_seconds == 16 and value.project_characters == 1)
assert(value.file_seconds == 6 and value.file_characters == 0)
local data = stats._test.state()
assert(data.projects[first_value.root].files[first_value.file].seconds == 10)
assert(data.projects[first_value.root].files[first_value.file].characters == 1)
clock = 20 * 1000000000
stats.pause()
stats.record_char(second, "x")
clock = 40 * 1000000000
stats.tick()
value = stats.summary(second)
assert(value.paused and value.project_seconds == 20 and value.file_seconds == 10)
assert(value.project_characters == 1, "paused stats counted typed characters")
stats.setup({ keymaps = false, timer = false, state_path = state_path, now = function() return clock end, root_resolver = function() return project end })
assert(stats._test.state().paused, "paused state was not restored")
stats.record_char(second, "x")
assert(stats.summary(second).project_characters == 1, "reloaded paused stats counted typed characters")
stats.resume()
clock = 45 * 1000000000
stats.record_char(second, "y")
stats.tick()
value = stats.summary(second)
assert(not value.paused and value.project_seconds == 25 and value.project_characters == 2)
stats.stop()
clock = 60 * 1000000000
stats.tick()
assert(stats.summary(second).project_seconds == 25, "stopped timer changed totals")
assert(vim.fn.filereadable(state_path) == 1, "state was not persisted")

stats.setup({ keymaps = false, timer = false, state_path = state_path, now = function() return clock end, root_resolver = function() return project end })
vim.api.nvim_set_current_buf(second)
assert(stats.summary(second).project_characters == 2, "saved state was not reloaded")
assert(vim.fn.exists(":ProjectStatsPause") == 2 and vim.fn.exists(":ProjectStatsResume") == 2)
assert(stats._test.format_seconds(3661) == "1h 01m 01s")
vim.fn.delete(vim.fn.fnamemodify(state_path, ":h"), "rf")
vim.fn.delete(project, "rf")
print("project_stats: ok")
