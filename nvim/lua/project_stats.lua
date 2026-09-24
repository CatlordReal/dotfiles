local M = {}

local defaults = {
  keymaps = true,
  timer = true,
  interval_ms = 15000,
  state_path = nil,
  now = nil,
  root_resolver = nil,
}

local options = vim.deepcopy(defaults)
local state = { version = 1, enabled = false, projects = {} }
local active
local last_tick
local timer
local runtime_key = "dotfiles_project_stats_runtime"

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Project stats" })
end

local function now()
  return options.now and options.now() or vim.uv.hrtime()
end

local function path()
  return options.state_path or (vim.fn.stdpath("state") .. "/project-stats.json")
end

local function clean_state(value)
  if type(value) ~= "table" or type(value.projects) ~= "table" then
    return { version = 1, enabled = false, projects = {} }
  end
  value.version = 1
  value.enabled = value.enabled == true
  return value
end

local function load()
  if vim.fn.filereadable(path()) ~= 1 then
    return { version = 1, enabled = false, projects = {} }
  end
  local lines = vim.fn.readfile(path())
  if #lines == 0 then return { version = 1, enabled = false, projects = {} } end
  local ok, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
  return ok and clean_state(decoded) or { version = 1, enabled = false, projects = {} }
end

local function save()
  vim.fn.mkdir(vim.fn.fnamemodify(path(), ":h"), "p")
  local temporary = path() .. ".tmp"
  local ok, err = pcall(vim.fn.writefile, { vim.json.encode(state) }, temporary)
  if not ok then
    notify("Could not save stats: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end
  local renamed, rename_err = os.rename(temporary, path())
  if not renamed then
    vim.fn.delete(temporary)
    notify("Could not save stats: " .. tostring(rename_err), vim.log.levels.ERROR)
    return false
  end
  return true
end

local function project_root(file)
  if options.root_resolver then return options.root_resolver(file) end
  return vim.fs.root(file, { ".git" }) or vim.fn.getcwd()
end

local function target(buffer)
  if not vim.api.nvim_buf_is_valid(buffer) or not vim.bo[buffer].buflisted then return nil end
  local file = vim.api.nvim_buf_get_name(buffer)
  if file == "" then return nil end
  local root = project_root(file)
  if type(root) ~= "string" or root == "" then return nil end
  return { project = vim.fs.normalize(root), file = vim.fs.normalize(file) }
end

local function bucket(item)
  local project = state.projects[item.project]
  if not project then
    project = { seconds = 0, characters = 0, files = {} }
    state.projects[item.project] = project
  end
  local file = project.files[item.file]
  if not file then
    file = { seconds = 0, characters = 0 }
    project.files[item.file] = file
  end
  return project, file
end

local function add_seconds(item, seconds)
  if not item or seconds <= 0 then return end
  local project, file = bucket(item)
  project.seconds = project.seconds + seconds
  file.seconds = file.seconds + seconds
end

function M.tick()
  if not state.enabled or not active or not last_tick then return end
  local elapsed = math.max(0, (now() - last_tick) / 1000000000)
  add_seconds(active, elapsed)
  last_tick = now()
end

function M.activate(buffer)
  if not state.enabled then return end
  M.tick()
  active = target(buffer or vim.api.nvim_get_current_buf())
  last_tick = now()
end

local function pause()
  M.tick()
  active, last_tick = nil, nil
  save()
end

function M.record_char(buffer, character)
  if not state.enabled then return end
  local item = target(buffer)
  if not item or type(character) ~= "string" then return end
  local amount = vim.fn.strchars(character)
  if amount < 1 then return end
  local project, file = bucket(item)
  project.characters = project.characters + amount
  file.characters = file.characters + amount
end

function M.start()
  if state.enabled then
    M.activate()
    notify("Already recording")
    return
  end
  state.enabled = true
  M.activate()
  save()
  notify("Recording project stats")
end

function M.stop()
  if not state.enabled then
    notify("Recording already stopped")
    return
  end
  pause()
  state.enabled = false
  save()
  notify("Stopped project stats")
end

function M.toggle()
  if state.enabled then M.stop() else M.start() end
end

local function format_seconds(seconds)
  seconds = math.floor(seconds or 0)
  return string.format("%dh %02dm %02ds", math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), seconds % 60)
end

function M.summary(buffer)
  M.tick()
  local item = target(buffer or vim.api.nvim_get_current_buf())
  if not item then return nil end
  local project = state.projects[item.project] or { seconds = 0, characters = 0, files = {} }
  local file = project.files[item.file] or { seconds = 0, characters = 0 }
  return {
    root = item.project,
    file = item.file,
    enabled = state.enabled,
    project_seconds = project.seconds,
    project_characters = project.characters,
    file_seconds = file.seconds,
    file_characters = file.characters,
  }
end

function M.show()
  local value = M.summary()
  if not value then
    notify("Save a file before showing project stats", vim.log.levels.WARN)
    return
  end
  local lines = {
    "Project stats", "",
    "Recording: " .. (value.enabled and "on" or "off"),
    "Project: " .. value.root,
    "Project time: " .. format_seconds(value.project_seconds),
    "Project typed: " .. value.project_characters .. " characters",
    "", "File: " .. value.file,
    "File time: " .. format_seconds(value.file_seconds),
    "File typed: " .. value.file_characters .. " characters",
  }
  vim.cmd("botright new")
  local buffer = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
  vim.bo[buffer].buftype, vim.bo[buffer].bufhidden, vim.bo[buffer].modifiable = "nofile", "wipe", false
end

local function recording_path(item)
  local directory = vim.fn.stdpath("state") .. "/asciinema"
  vim.fn.mkdir(directory, "p")
  local name = vim.fn.fnamemodify(item.project, ":t"):gsub("[^%w._-]", "-")
  return string.format("%s/%s-%s.cast", directory, name, os.date("%Y%m%d-%H%M%S"))
end

function M.terminal_record()
  if vim.fn.has("linux") ~= 1 then
    notify("Terminal recording is available on Linux", vim.log.levels.WARN)
    return false
  end
  if vim.fn.executable("asciinema") ~= 1 then
    notify("Install asciinema to record a terminal", vim.log.levels.WARN)
    return false
  end
  local item = target(vim.api.nvim_get_current_buf())
  if not item then
    notify("Save a project file before recording", vim.log.levels.WARN)
    return false
  end
  local output = recording_path(item)
  vim.cmd("botright new")
  local job = vim.fn.termopen({ "asciinema", "rec", output }, { cwd = item.project })
  if job <= 0 then
    vim.api.nvim_buf_delete(0, { force = true })
    notify("Could not start asciinema", vim.log.levels.ERROR)
    return false
  end
  vim.cmd("startinsert")
  notify("Recording terminal: " .. output)
  return output
end

function M.setup(overrides)
  options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), overrides or {})
  local previous = vim.g[runtime_key]
  if previous and previous.timer then
    previous.timer:stop()
    previous.timer:close()
  end
  state = load()
  active, last_tick = nil, nil
  local group = vim.api.nvim_create_augroup("dotfiles_project_stats", { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter", "InsertEnter", "CursorMoved", "CursorMovedI" }, {
    group = group,
    callback = function(args) M.activate(args.buf) end,
  })
  vim.api.nvim_create_autocmd("InsertCharPre", {
    group = group,
    callback = function(args) M.record_char(args.buf, vim.v.char) end,
  })
  vim.api.nvim_create_autocmd({ "FocusLost", "VimSuspend", "VimLeavePre" }, { group = group, callback = pause })
  vim.api.nvim_create_autocmd({ "FocusGained", "VimResume" }, { group = group, callback = function() M.activate() end })
  vim.api.nvim_create_user_command("ProjectStatsStart", M.start, {})
  vim.api.nvim_create_user_command("ProjectStatsStop", M.stop, {})
  vim.api.nvim_create_user_command("ProjectStatsToggle", M.toggle, {})
  vim.api.nvim_create_user_command("ProjectStatsShow", M.show, {})
  vim.api.nvim_create_user_command("ProjectTerminalRecord", M.terminal_record, {})
  if options.keymaps then
    vim.keymap.set("n", "<leader>wT", M.toggle, { desc = "Toggle Project Stats" })
    vim.keymap.set("n", "<leader>wS", M.show, { desc = "Show Project Stats" })
    vim.keymap.set("n", "<leader>wR", M.terminal_record, { desc = "Record Linux Terminal" })
  end
  if options.timer and vim.uv.new_timer then
    timer = vim.uv.new_timer()
    timer:start(options.interval_ms, options.interval_ms, vim.schedule_wrap(function()
      M.tick()
      save()
    end))
  else
    timer = nil
  end
  vim.g[runtime_key] = { timer = timer }
  if state.enabled then M.activate() end
  return M
end

M._test = { state = function() return vim.deepcopy(state) end, format_seconds = format_seconds, recording_path = recording_path }

return M
