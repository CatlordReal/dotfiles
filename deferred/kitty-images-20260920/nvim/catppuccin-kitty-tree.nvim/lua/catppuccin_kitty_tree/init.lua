local M = {}
local ns = vim.api.nvim_create_namespace("catppuccin_kitty_tree")
local config = { enabled = true, cols = 1, scale = 1, fit = "contain",
  align_x = "center", align_y = "center",
  assets = vim.fn.stdpath("config") .. "/icons/catppuccin/vscode-icons/dist" }
local atlas, images, views, states, links = nil, {}, {}, {}, {}
local initialized, subscribed, queued, warned = false, false, false, false
local flavours = { latte = true, frappe = true, macchiato = true, mocha = true }
local schedule

function M.flavour()
  local name = (vim.g.colors_name or ""):match("^catppuccin%-(.+)$")
  if flavours[name] then return name end
  if flavours[vim.g.catppuccin_flavour] then return vim.g.catppuccin_flavour end
  return vim.o.background == "light" and "latte" or "mocha"
end

local function available()
  return config.enabled and vim.o.termguicolors and not vim.env.TMUX and not vim.env.STY
    and (config.test_mode or ((vim.env.KITTY_WINDOW_ID or vim.env.TERM == "xterm-kitty")
      and #vim.api.nvim_list_uis() > 0))
end

local function clear_images()
  for _, image in pairs(images) do image:delete() end
  images = {}
end

local function clear_marks(buf)
  if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1) end
end

local function texture(slot)
  local path = atlas:resolve(slot.entry, M.flavour())
  if not path then return nil end
  slot.path = path
  local image = images[path]
  if image and image.state ~= "deleted" then return image end
  local ok, result = pcall(require("kitty_cells").new, {
    path = path, cols = config.cols, rows = 1, scale = config.scale, fit = config.fit,
    align_x = config.align_x, align_y = config.align_y,
    on_ready = function() schedule(false) end,
    on_error = function(err)
      if not warned then
        warned = true
        vim.notify("Catppuccin tree icons: " .. err .. ". Native icons remain available.", vim.log.levels.WARN)
      end
    end,
  })
  if not ok then
    if not warned then warned = true; vim.notify(tostring(result), vim.log.levels.WARN) end
    return nil
  end
  images[path] = result
  return result
end

local function paint(buf, view)
  clear_marks(buf)
  if not available() or vim.api.nvim_buf_get_changedtick(buf) ~= view.tick then return end
  for _, slot in ipairs(view.slots) do
    if slot.width >= config.cols then
      local image = texture(slot)
      local lines = image and image:lines()
      if lines then
        vim.api.nvim_buf_set_extmark(buf, ns, slot.row, slot.col, {
          virt_text = lines[1], virt_text_pos = "overlay", hl_mode = "replace",
          priority = 250, right_gravity = false,
        })
      end
    end
  end
end

local function collect_mini(buf)
  local mini = package.loaded["mini.files"]
  if not mini or not vim.api.nvim_buf_is_valid(buf) then return end
  local slots, branch = {}, {}
  local explorer = mini.get_explorer_state()
  for _, path in ipairs(explorer and explorer.branch or {}) do branch[path] = true end
  for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    local start, finish = line:match("^/%d+/().-()/")
    if start then
      local ok, entry = pcall(mini.get_fs_entry, buf, i)
      if ok and entry then
        slots[#slots + 1] = { row = i - 1, col = start - 1,
          width = vim.fn.strdisplaywidth(line:sub(start, finish - 1)),
          entry = { name = entry.name, path = entry.path, kind = entry.fs_type,
            expanded = branch[entry.path] == true } }
      end
    end
  end
  views[buf] = { slots = slots, tick = vim.api.nvim_buf_get_changedtick(buf), kind = "mini" }
end

local function collect_neo(state)
  local buf = state.bufnr
  if not buf or not state.tree or not vim.api.nvim_buf_is_valid(buf) then return end
  local slots = {}
  local native_ns = require("neo-tree.ui.highlights").ns_id
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, native_ns, 0, -1, { details = true })) do
    local group = mark[4].hl_group
    if type(group) == "string" and group:match("^CatppuccinKittySlot") then
      local node = state.tree:get_node(mark[2] + 1)
      if node and (node.type == "file" or node.type == "directory") then
        local line = vim.api.nvim_buf_get_lines(buf, mark[2], mark[2] + 1, false)[1] or ""
        slots[#slots + 1] = { row = mark[2], col = mark[3],
          width = vim.fn.strdisplaywidth(line:sub(mark[3] + 1, mark[4].end_col)),
          entry = { name = node.name, path = node.path or node:get_id(), kind = node.type,
            expanded = node:is_expanded(), root = node:get_depth() == 1 } }
      end
    end
  end
  views[buf] = { slots = slots, tick = vim.api.nvim_buf_get_changedtick(buf), kind = "neo" }
end

local function sweep(recollect)
  local visible = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    visible[buf] = true
    if recollect and vim.bo[buf].filetype == "minifiles" then collect_mini(buf) end
  end
  if recollect then
    for buf, state in pairs(states) do if visible[buf] then collect_neo(state) end end
  end
  local used = {}
  for buf, view in pairs(views) do
    if not visible[buf] or not vim.api.nvim_buf_is_valid(buf) then
      clear_marks(buf); views[buf] = nil; states[buf] = nil
    else
      paint(buf, view)
      if available() then
        for _, slot in ipairs(view.slots) do if slot.path then used[slot.path] = true end end
      end
    end
  end
  for path, image in pairs(images) do
    if not used[path] then image:delete(); images[path] = nil end
  end
end

local recollect_pending = false
schedule = function(recollect)
  recollect_pending = recollect_pending or recollect
  if queued then return end
  queued = true
  vim.defer_fn(function()
    queued = false
    local collect = recollect_pending
    recollect_pending = false
    sweep(collect)
  end, 20)
end

-- Native icon component remains in the buffer. A linked highlight identifies its
-- exact rendered column, so no indent/filename guesses or text rewrites are needed.
function M.neo_icon(component, node, state)
  M.setup()
  -- Neo-tree's redraw() does not emit AFTER_RENDER (show_nodes() does).
  -- A deferred collection from this component covers both public render paths.
  if state.bufnr then states[state.bufnr] = state; schedule(true) end
  if not subscribed then
    subscribed = true
    local events = require("neo-tree.events")
    events.subscribe({ id = "catppuccin_kitty_tree", event = events.AFTER_RENDER, handler = function(s)
      if s and s.bufnr then states[s.bufnr] = s; collect_neo(s); schedule(false) end
    end })
  end
  local result = require("neo-tree.sources.common.components").icon(component, node, state)
  local original = result.highlight or "NeoTreeFileIcon"
  local group = "CatppuccinKittySlot" .. original
  links[group] = original
  vim.api.nvim_set_hl(0, group, { link = original })
  result.highlight = group
  return result
end

function M.enable()
  config.enabled, warned = true, false
  schedule(true)
end

function M.disable()
  config.enabled = false
  for buf in pairs(views) do clear_marks(buf) end
  clear_images()
end

function M.toggle()
  if config.enabled then M.disable() else M.enable() end
end

function M.refresh()
  for buf in pairs(views) do clear_marks(buf) end
  clear_images()
  atlas, warned = require("catppuccin_kitty_tree.atlas").new(config.assets), false
  schedule(true)
end

function M.status()
  local ready, pending, count = 0, 0, 0
  for _, image in pairs(images) do
    if image.state == "ready" then ready = ready + 1 else pending = pending + 1 end
  end
  for buf in pairs(views) do
    if vim.api.nvim_buf_is_valid(buf) then count = count + #vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {}) end
  end
  return { enabled = config.enabled, available = not not available(), flavour = M.flavour(),
    ready = ready, pending = pending, placements = count }
end

function M.setup(opts)
  if opts then
    config = vim.tbl_extend("force", config, opts)
    assert(config.cols == 1 or config.cols == 2, "Tree icons must use one or two columns")
  end
  atlas = atlas or require("catppuccin_kitty_tree.atlas").new(config.assets)
  if initialized then if opts then M.refresh() end; return M end
  initialized = true
  local group = vim.api.nvim_create_augroup("CatppuccinKittyTree", { clear = true })
  vim.api.nvim_create_autocmd("User", { group = group, pattern = { "MiniFilesBufferUpdate", "MiniFilesExplorerClose" },
    callback = function(event)
      if event.data and event.data.buf_id then collect_mini(event.data.buf_id) end
      schedule(true)
    end })
  vim.api.nvim_create_autocmd({ "BufWinEnter", "BufWinLeave", "WinClosed", "TextChanged", "TextChangedI" }, {
    group = group, callback = function(event)
      if next(views) or (event.buf and vim.api.nvim_buf_is_valid(event.buf) and vim.bo[event.buf].filetype == "minifiles") then
        schedule(true)
      end
    end })
  vim.api.nvim_create_autocmd("BufWipeout", { group = group, callback = function(event)
    views[event.buf], states[event.buf] = nil, nil; schedule(false)
  end })
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = function()
    for name, link in pairs(links) do vim.api.nvim_set_hl(0, name, { link = link }) end
    M.refresh()
  end })
  vim.api.nvim_create_autocmd("VimLeavePre", { group = group, callback = M.disable })
  for suffix, callback in pairs({ Enable = M.enable, Disable = M.disable, Toggle = M.toggle, Refresh = M.refresh }) do
    vim.api.nvim_create_user_command("CatppuccinTreeIcons" .. suffix, callback, {})
  end
  return M
end

M.namespace = ns
return M
