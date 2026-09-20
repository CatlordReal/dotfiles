local M = {}
local terminal = require("kitty_cells.terminal")
local diacritics = require("kitty_cells.diacritics")
local root = debug.getinfo(1, "S").source:sub(2):match("^(.*)/lua/kitty_cells/init.lua$")
local ns = vim.api.nvim_create_namespace("kitty_cells")
local config = { python = "python3", fit = "contain", scale = 1, align_x = "center", align_y = "center" }
local handles, cache, queue, jobs = {}, {}, {}, {}
local active, next_id, initialized, stopping = 0, (vim.uv.hrtime() % 0xEFFFFF) + 0x10000, false, false
local cache_dir
local Image = {}
Image.__index = Image

local function integer(value, name, maximum)
  assert(type(value) == "number" and value >= 1 and value == math.floor(value)
    and value <= maximum, name .. " must be an integer from 1 to " .. maximum)
  return value
end

local function cell_size()
  local size, err
  if type(config.cell_size) == "function" then size = config.cell_size()
  elseif config.cell_size then size = config.cell_size
  else size, err = terminal.cell_size() end
  assert(size, err)
  return { width = integer(size.width, "cell width", 16384), height = integer(size.height, "cell height", 16384) }
end

local function write(data)
  if config.writer then return config.writer(data) end
  assert(not vim.env.TMUX and not vim.env.STY, "kitty-cells: run directly in Kitty; multiplexers are not supported")
  assert(#vim.api.nvim_list_uis() > 0, "kitty-cells: a terminal UI is required")
  assert(vim.env.KITTY_WINDOW_ID or vim.env.TERM == "xterm-kitty", "kitty-cells: Kitty terminal required")
  terminal.write(data)
end

local function highlight(self)
  -- The foreground RGB encodes the 24-bit image ID, not a visual text color.
  vim.api.nvim_set_hl(0, self.highlight, { fg = ("#%06x"):format(self.id), nocombine = true })
end

local function fail(self, message)
  self.state, self.error = "error", tostring(message)
  if self.uploaded then pcall(terminal.delete, self.id, write); self.uploaded = false end
  -- Keep anchors for a later retry, but never leave stale image content visible.
  for _, mark in ipairs(self.marks) do
    if vim.api.nvim_buf_is_valid(mark.buf) then
      local pos = vim.api.nvim_buf_get_extmark_by_id(mark.buf, ns, mark.id, {})
      if #pos > 0 then
        vim.api.nvim_buf_set_extmark(mark.buf, ns, pos[1], pos[2], { id = mark.id, right_gravity = false })
      end
    end
  end
  if self.options.on_error then
    local ok, err = pcall(self.options.on_error, self.error, self)
    if not ok then vim.notify("kitty-cells on_error: " .. tostring(err), vim.log.levels.ERROR) end
  else vim.notify("kitty-cells: " .. self.error, vim.log.levels.ERROR) end
end

local pump
pump = function()
  while active < 2 and #queue > 0 and not stopping do
    local task = table.remove(queue, 1)
    active = active + 1
    local function complete(result)
      vim.schedule(function()
        jobs[task.key] = nil
        active = active - 1
        if stopping then return end
        local entry = cache[task.key]
        if result.code == 0 then
          local ok, metadata = pcall(vim.json.decode, result.stdout)
          if ok then entry.metadata = metadata else entry.error = "Invalid renderer response: " .. tostring(metadata) end
        else entry.error = vim.trim(result.stderr or "Renderer failed") end
        entry.done = true
        for _, callback in ipairs(entry.waiters) do
          local ok, err = pcall(callback, entry)
          if not ok then vim.notify("kitty-cells: " .. tostring(err), vim.log.levels.ERROR) end
        end
        entry.waiters = nil
        pump()
      end)
    end
    local ok, job = pcall(vim.system, task.argv, { text = true, timeout = 30000 }, complete)
    if ok then jobs[task.key] = job else complete({ code = 1, stderr = tostring(job) }) end
  end
end

function Image:lines()
  assert(self.state ~= "deleted", "Image was deleted")
  if self.state ~= "ready" then return nil, self.error or "Image is still rendering" end
  local lines = {}
  for row = 1, self.rows do
    local chars = {}
    for col = 1, self.cols do
      chars[col] = vim.fn.nr2char(0x10EEEE) .. vim.fn.nr2char(diacritics[row]) .. vim.fn.nr2char(diacritics[col])
    end
    lines[row] = { { table.concat(chars), self.highlight } }
  end
  return lines
end

function Image:unplace()
  for _, mark in ipairs(self.marks or {}) do
    if vim.api.nvim_buf_is_valid(mark.buf) then pcall(vim.api.nvim_buf_del_extmark, mark.buf, ns, mark.id) end
  end
  self.marks, self.placement = {}, nil
  return self
end

local function draw(self)
  if not self.placement or self.state ~= "ready" then return end
  local lines = assert(self:lines())
  for index, mark in ipairs(self.marks) do
    if not vim.api.nvim_buf_is_valid(mark.buf) then return end
    local pos = vim.api.nvim_buf_get_extmark_by_id(mark.buf, ns, mark.id, {})
    if #pos > 0 then
      vim.api.nvim_buf_set_extmark(mark.buf, ns, pos[1], pos[2], {
        id = mark.id, virt_text = lines[index], virt_text_pos = "overlay",
        hl_mode = "replace", priority = self.placement.priority or 200,
        right_gravity = false, undo_restore = true,
      })
    end
  end
end

-- Reserve ASCII spaces in the consumer's layout. This method never edits text.
-- row and col are zero-based buffer row and byte column.
function Image:place(opts)
  assert(self.state ~= "deleted", "Image was deleted")
  opts = vim.tbl_extend("force", { buf = 0, row = 0, col = 0 }, opts or {})
  if opts.buf == 0 then opts.buf = vim.api.nvim_get_current_buf() end
  assert(vim.api.nvim_buf_is_valid(opts.buf), "Invalid buffer")
  assert(opts.row >= 0 and opts.row == math.floor(opts.row), "row must be a nonnegative integer")
  assert(opts.col >= 0 and opts.col == math.floor(opts.col), "col must be a nonnegative byte column")
  assert(opts.row + self.rows <= vim.api.nvim_buf_line_count(opts.buf), "Reserve all rectangle rows before placing")
  local text = vim.api.nvim_buf_get_lines(opts.buf, opts.row, opts.row + self.rows, true)
  local display_col
  for _, line in ipairs(text) do
    assert(line:sub(opts.col + 1, opts.col + self.cols) == string.rep(" ", self.cols),
      "Reserve a rectangle of ASCII spaces before placing")
    local width = vim.api.nvim_buf_call(opts.buf, function() return vim.fn.strdisplaywidth(line:sub(1, opts.col)) end)
    assert(not display_col or display_col == width, "Rectangle rows must start at the same display column")
    display_col = width
  end
  self:unplace()
  self.placement = opts
  for row = opts.row, opts.row + self.rows - 1 do
    local id = vim.api.nvim_buf_set_extmark(opts.buf, ns, row, opts.col, { right_gravity = false })
    self.marks[#self.marks + 1] = { buf = opts.buf, id = id }
  end
  draw(self)
  return self
end

function Image:delete()
  if self.state == "deleted" then return end
  self:unplace()
  self.generation = self.generation + 1
  if self.uploaded then pcall(terminal.delete, self.id, write) end
  self.state = "deleted"
  handles[self.id] = nil
  vim.api.nvim_set_hl(0, self.highlight, {})
end

function Image:refresh()
  assert(self.state ~= "deleted", "Image was deleted")
  local size = cell_size()
  local stat = assert(vim.uv.fs_stat(self.path), "Source file no longer exists: " .. self.path)
  assert(stat.type == "file", "Source must be a file")
  local width, height = self.cols * size.width, self.rows * size.height
  assert(width <= 16384 and height <= 16384 and width * height <= 64000000, "Image canvas exceeds pixel limit")
  local o = self.options
  local key = vim.fn.sha256(vim.json.encode({ self.path, stat.size, stat.mtime.sec, stat.mtime.nsec,
    width, height, o.fit, o.scale, o.align_x, o.align_y }))
  if self.key == key and (self.state == "ready" or self.state == "loading") then return self end
  self.key, self.state, self.error = key, "loading", nil
  self.generation = self.generation + 1
  local generation = self.generation
  local function ready(entry)
    if self.state == "deleted" or self.generation ~= generation then return end
    if entry.error then fail(self, entry.error); return end
    local ok, err = pcall(function()
      local file = assert(io.open(entry.path, "rb"))
      local png = file:read("*a")
      file:close()
      highlight(self)
      terminal.upload(self.id, png, self.cols, self.rows, write)
      self.uploaded, self.state = true, "ready"
      self.cell_size, self.metadata = size, entry.metadata
      draw(self)
    end)
    if not ok then fail(self, err); return end
    if o.on_ready then
      local callback_ok, callback_err = pcall(o.on_ready, self)
      if not callback_ok then vim.notify("kitty-cells on_ready: " .. tostring(callback_err), vim.log.levels.ERROR) end
    end
  end
  if cache[key] and cache[key].done and cache[key].error then cache[key] = nil end
  if cache[key] then
    if cache[key].done then vim.schedule(function() ready(cache[key]) end)
    else table.insert(cache[key].waiters, ready) end
    return self
  end
  if not cache_dir then
    cache_dir = vim.fn.tempname() .. "-kitty-cells"
    vim.fn.mkdir(cache_dir, "p", 448)
  end
  local output = cache_dir .. "/" .. key .. ".png"
  cache[key] = { path = output, waiters = { ready } }
  queue[#queue + 1] = { key = key, argv = { config.python, root .. "/scripts/render.py",
    "--source", self.path, "--output", output, "--width", tostring(width), "--height", tostring(height),
    "--fit", o.fit, "--scale", tostring(o.scale), "--align-x", o.align_x, "--align-y", o.align_y } }
  pump()
  return self
end

function M.new(opts)
  M.setup()
  assert(type(opts) == "table" and type(opts.path) == "string", "new() requires a path")
  assert(vim.o.termguicolors, "kitty-cells requires termguicolors")
  local o = vim.tbl_extend("force", config, opts)
  assert(vim.tbl_contains({ "contain", "cover", "fill", "none" }, o.fit), "Invalid fit mode")
  assert(type(o.scale) == "number" and o.scale > 0 and o.scale < math.huge, "scale must be positive and finite")
  assert(vim.tbl_contains({ "left", "center", "right" }, o.align_x), "Invalid align_x")
  assert(vim.tbl_contains({ "top", "center", "bottom" }, o.align_y), "Invalid align_y")
  assert(o.on_ready == nil or type(o.on_ready) == "function", "on_ready must be a function")
  assert(o.on_error == nil or type(o.on_error) == "function", "on_error must be a function")
  local cols, rows = integer(o.cols or 1, "cols", #diacritics), integer(o.rows or 1, "rows", #diacritics)
  next_id = next_id % 0xFFFFFF + 1
  while handles[next_id] do next_id = next_id % 0xFFFFFF + 1 end
  local self = setmetatable({ id = next_id, highlight = "KittyCells" .. next_id, cols = cols, rows = rows,
    path = vim.fn.fnamemodify(vim.fn.expand(o.path), ":p"), options = o, marks = {}, generation = 0 }, Image)
  self:refresh()
  handles[self.id] = self
  return self
end

function M.clear()
  local copy = vim.tbl_values(handles)
  for _, item in ipairs(copy) do item:delete() end
end

function M.refresh()
  for _, item in pairs(handles) do
    local ok, err = pcall(item.refresh, item)
    if not ok then fail(item, err) end
  end
end

function M.setup(opts)
  if opts then config = vim.tbl_extend("force", config, opts) end
  if initialized then return M end
  initialized = true
  local group = vim.api.nvim_create_augroup("KittyCells", { clear = true })
  vim.api.nvim_create_autocmd({ "VimResized", "FocusGained" }, { group = group, callback = M.refresh })
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = function()
    for _, item in pairs(handles) do highlight(item) end
  end })
  vim.api.nvim_create_autocmd("BufWipeout", { group = group, callback = function(event)
    for _, item in ipairs(vim.tbl_values(handles)) do
      if item.placement and item.placement.buf == event.buf then item:delete() end
    end
  end })
  vim.api.nvim_create_autocmd("VimLeavePre", { group = group, callback = function()
    stopping = true
    M.clear()
    for _, job in pairs(jobs) do job:kill(15) end
    if cache_dir then vim.fn.delete(cache_dir, "rf") end
  end })
  vim.api.nvim_create_user_command("KittyCellsDemo", function() require("kitty_cells.demo").open() end, {})
  vim.api.nvim_create_user_command("KittyCellsClear", M.clear, {})
  vim.api.nvim_create_user_command("KittyCellsRefresh", M.refresh, {})
  return M
end

M.namespace = ns
return M
