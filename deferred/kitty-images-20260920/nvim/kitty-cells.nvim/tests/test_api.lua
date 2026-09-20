-- Run: nvim --headless -u NONE -l tests/test_api.lua (from plugin root).
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.o.termguicolors = true
local cells = require("kitty_cells")
local terminal = require("kitty_cells.terminal")
local writes, errors, callbacks = {}, {}, 0
cells.setup({ cell_size = { width = 10, height = 20 }, writer = function(data) writes[#writes + 1] = data end })
local source = vim.fn.getcwd() .. "/examples/square.svg"
local function new(opts)
  return cells.new(vim.tbl_extend("force", {
    path = source, on_error = function(err) errors[#errors + 1] = err end,
    on_ready = function() callbacks = callbacks + 1 end,
  }, opts or {}))
end
local function wait(image)
  assert(vim.wait(10000, function() return image.state ~= "loading" end, 10), "render timed out")
  assert(image.state == "ready", image.error)
end

local square = new()
wait(square)
assert(square.metadata.canvas.width == 10 and square.metadata.canvas.height == 20)
assert(square.metadata.placement.width == 10 and square.metadata.placement.height == 10)
assert(square.metadata.placement.x == 0 and square.metadata.placement.y == 5)
local rows = assert(square:lines())
assert(#rows == 1 and vim.fn.strdisplaywidth(rows[1][1][1]) == 1)
assert(vim.api.nvim_get_hl(0, { name = square.highlight }).fg == square.id)
assert(writes[1]:find("a=T,f=100,t=d,U=1,q=2,i=" .. square.id, 1, true))
assert(writes[1]:find("c=1,r=1,m=0", 1, true))
local payload = writes[1]:match(";(.*)\27\\$")
assert(vim.base64.decode(payload):sub(1, 8) == "\137PNG\r\n\26\n")

local rect = new({ cols = 2, rows = 3 })
local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "x  x", "x  x", "x  x" })
rect:place({ buf = buf, row = 0, col = 1 }) -- Placement before conversion finishes.
wait(rect)
assert(#rect:lines() == 3)
for _, chunks in ipairs(rect:lines()) do assert(vim.fn.strdisplaywidth(chunks[1][1]) == 2) end
local marks = vim.api.nvim_buf_get_extmarks(buf, cells.namespace, 0, -1, { details = true })
assert(#marks == 3 and marks[1][4].virt_text_pos == "overlay")
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(buf, 0, -1, true), { "x  x", "x  x", "x  x" }))
assert(not pcall(rect.place, rect, { buf = buf, row = 1, col = 1 }))
assert(#vim.api.nvim_buf_get_extmarks(buf, cells.namespace, 0, -1, {}) == 3, "invalid move must preserve placement")
vim.api.nvim_buf_set_lines(buf, 0, 0, false, { "prefix" })
marks = vim.api.nvim_buf_get_extmarks(buf, cells.namespace, 0, -1, {})
assert(marks[1][2] == 1 and marks[3][2] == 3, "extmarks must follow inserted lines")
rect:unplace()
assert(#vim.api.nvim_buf_get_extmarks(buf, cells.namespace, 0, -1, {}) == 0)
rect:place({ buf = buf, row = 1, col = 1 })
vim.api.nvim_buf_delete(buf, { force = true })
assert(rect.state == "deleted")
assert(writes[#writes]:find("a=d,d=I,q=2,i=" .. rect.id, 1, true))

local canceled = new({ scale = 0.7 })
canceled:delete()
vim.wait(2000, function() return false end, 20)
assert(canceled.state == "deleted")
for _, data in ipairs(writes) do assert(not data:find("a=T,f=100,t=d,U=1,q=2,i=" .. canceled.id .. ",", 1, true)) end

local count = #writes
square:refresh()
assert(#writes == count, "unchanged refresh must reuse image")
cells.setup({ cell_size = { width = 12, height = 24 } })
cells.refresh()
wait(square)
assert(square.metadata.canvas.width == 12 and square.metadata.canvas.height == 24)
vim.api.nvim_set_hl(0, square.highlight, {})
vim.api.nvim_exec_autocmds("ColorScheme", {})
assert(vim.api.nvim_get_hl(0, { name = square.highlight }).fg == square.id)

for _, opts in ipairs({ { cols = 0 }, { rows = 1.5 }, { scale = 0 }, { scale = math.huge }, { fit = "bad" } }) do
  assert(not pcall(new, opts), "invalid option accepted")
end
local chunks = {}
terminal.upload(123, string.rep("x", 10000), 2, 3, function(data) chunks[#chunks + 1] = data end)
local reconstructed = {}
for i, data in ipairs(chunks) do
  local chunk = data:match(";(.*)\27\\$")
  assert(#chunk <= 4096)
  assert(data:find("m=" .. (i == #chunks and "0" or "1"), 1, true))
  reconstructed[#reconstructed + 1] = chunk
end
assert(vim.base64.decode(table.concat(reconstructed)) == string.rep("x", 10000))

-- A failed refresh removes stale pixels, preserves anchors, and permits retry.
local failures = {}
local retry = new({ on_error = function(err) failures[#failures + 1] = err end })
wait(retry)
local retry_buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(retry_buf, 0, -1, false, { " " })
retry:place({ buf = retry_buf })
cells.setup({ python = "/usr/bin/false", cell_size = { width = 13, height = 26 } })
retry:refresh()
assert(vim.wait(10000, function() return retry.state ~= "loading" end, 10))
assert(retry.state == "error" and #failures == 1 and not retry.uploaded)
local retry_marks = vim.api.nvim_buf_get_extmarks(retry_buf, cells.namespace, 0, -1, { details = true })
assert(#retry_marks == 1 and retry_marks[1][4].virt_text == nil, "failed refresh must hide stale placeholders")
assert(writes[#writes]:find("a=d,d=I,q=2,i=" .. retry.id, 1, true))
cells.setup({ python = "python3" })
retry:refresh() -- Same source and geometry as failed request; must rerun conversion.
wait(retry)
retry_marks = vim.api.nvim_buf_get_extmarks(retry_buf, cells.namespace, 0, -1, { details = true })
assert(retry_marks[1][4].virt_text ~= nil and retry.metadata.canvas.width == 13)
retry:delete()

-- Consumer callback failures must not corrupt the successfully uploaded image.
local original_notify = vim.notify
local notifications = {}
vim.notify = function(message) notifications[#notifications + 1] = message end
local callback_error = new({ on_ready = function() error("consumer callback failed") end })
wait(callback_error)
assert(callback_error.state == "ready" and callback_error.uploaded)
assert(#notifications == 1 and notifications[1]:find("consumer callback failed", 1, true))
vim.notify = original_notify
assert(#errors == 0, vim.inspect(errors))
cells.clear()
assert(square.state == "deleted")
print("PASS: cell geometry, PNG wire payload, placeholders, extmarks, lifecycle, resize, validation, chunking")
vim.cmd("qa!")
