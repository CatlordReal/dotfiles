local M = {}

local defaults = {
  compiler = "g++",
  standard = "c++20",
  flags = {},
  program_args = {},
  project = {
    kind = "cmake",
    root = "",
    build_dir = "build",
    build_type = "Debug",
    target = "",
    build_command = { "cmake", "--build", "build" },
    run_command = {},
  },
}

local state_path
local cache_path
local settings
local terminal
local edit_project_settings

local function copy(value)
  return vim.deepcopy(value)
end

local function merge(base, overrides)
  return vim.tbl_deep_extend("force", copy(base), overrides or {})
end

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "C++ runner" })
end

local function load()
  local file = io.open(state_path, "r")
  if not file then
    return copy(defaults)
  end
  local content = file:read("*a")
  file:close()
  local ok, decoded = pcall(vim.json.decode, content)
  if not ok or type(decoded) ~= "table" then
    notify("Ignoring invalid saved settings", vim.log.levels.WARN)
    return copy(defaults)
  end
  local function argv(value)
    if type(value) ~= "table" then return false end
    for _, item in ipairs(value) do
      if type(item) ~= "string" then return false end
    end
    return true
  end
  local project = decoded.project
  local valid = (decoded.compiler == nil or type(decoded.compiler) == "string")
    and (decoded.standard == nil or type(decoded.standard) == "string")
    and (decoded.flags == nil or argv(decoded.flags))
    and (decoded.program_args == nil or argv(decoded.program_args))
  if project ~= nil then
    valid = valid and type(project) == "table"
      and (project.kind == nil or type(project.kind) == "string")
      and (project.root == nil or type(project.root) == "string")
      and (project.build_dir == nil or type(project.build_dir) == "string")
      and (project.build_type == nil or type(project.build_type) == "string")
      and (project.target == nil or type(project.target) == "string")
      and (project.build_command == nil or argv(project.build_command))
      and (project.run_command == nil or argv(project.run_command))
  end
  if not valid then
    notify("Ignoring malformed saved settings", vim.log.levels.WARN)
    return copy(defaults)
  end
  return merge(defaults, decoded)
end

local function save()
  vim.fn.mkdir(vim.fn.fnamemodify(state_path, ":h"), "p")
  local file, err = io.open(state_path, "w")
  if not file then
    notify("Could not save settings: " .. err, vim.log.levels.ERROR)
    return false
  end
  file:write(vim.json.encode(settings))
  file:close()
  return true
end

local function csv(value)
  if value == "" then
    return {}
  end
  local result = {}
  for item in value:gmatch("[^,]+") do
    item = vim.trim(item)
    if item ~= "" then
      table.insert(result, item)
    end
  end
  return result
end

local function csv_text(items)
  return table.concat(items or {}, ", ")
end

local function valid_argv(argv, label)
  if type(argv) ~= "table" or #argv == 0 or type(argv[1]) ~= "string" or argv[1] == "" then
    notify(label .. " command is not configured", vim.log.levels.ERROR)
    return false
  end
  for _, value in ipairs(argv) do
    if type(value) ~= "string" then
      notify(label .. " command must be an argv list", vim.log.levels.ERROR)
      return false
    end
  end
  return true
end

local function open_terminal(argv, options, on_exit)
  return terminal(argv, options or {}, on_exit)
end

local function default_terminal(argv, options, on_exit)
  vim.cmd("botright new")
  local window = vim.api.nvim_get_current_win()
  local buffer = vim.api.nvim_get_current_buf()
  vim.bo[buffer].buflisted = false
  vim.fn.termopen(argv, {
    cwd = options.cwd,
    on_exit = function(_, code)
      if on_exit then
        vim.schedule(function()
          on_exit(code)
        end)
      end
    end,
  })
  vim.cmd("startinsert")
  return {
    close = function()
      if vim.api.nvim_win_is_valid(window) then
        vim.api.nvim_win_close(window, true)
      end
    end,
  }
end

local function close_terminal(handle)
  if handle and handle.close then
    handle.close()
  end
end

local function output_path(source)
  local cache = cache_path
  vim.fn.mkdir(cache, "p")
  local hash = vim.fn.sha256(vim.fn.fnamemodify(source, ":p")):sub(1, 12)
  return string.format("%s/%s-%d", cache, hash, vim.uv.hrtime())
end

local function file_argv(source, output, values)
  local argv = { values.compiler, "-std=" .. values.standard }
  vim.list_extend(argv, values.flags or {})
  table.insert(argv, source)
  table.insert(argv, "-o")
  table.insert(argv, output)
  return argv
end

local function run_argv(output, values)
  local argv = { output }
  vim.list_extend(argv, values.program_args or {})
  return argv
end

function M.is_cpp_buffer()
  local source = vim.api.nvim_buf_get_name(0)
  local extension = vim.fn.fnamemodify(source, ":e"):lower()
  return vim.tbl_contains({ "cpp", "cxx", "cc", "c++", "cp" }, extension)
end

function M.run_file()
  local source = vim.api.nvim_buf_get_name(0)
  if source == "" then
    notify("Save C++ file before running", vim.log.levels.ERROR)
    return false
  end
  if not M.is_cpp_buffer() then
    notify("Current buffer is not a C++ source file", vim.log.levels.ERROR)
    return false
  end
  if vim.bo.modified then
    vim.cmd("write")
  end
  local values = copy(settings)
  local output = output_path(source)
  local compile = file_argv(source, output, values)
  if not valid_argv(compile, "Compiler") then
    return false
  end
  local compile_terminal
  compile_terminal = open_terminal(compile, { cwd = vim.fn.fnamemodify(source, ":h") }, function(code)
    if code ~= 0 then
      notify("Compile failed; program was not run", vim.log.levels.ERROR)
      return
    end
    close_terminal(compile_terminal)
    open_terminal(run_argv(output, values), { cwd = vim.fn.fnamemodify(source, ":h") }, function(run_code)
      if run_code ~= 0 then
        notify("Program exited with status " .. run_code, vim.log.levels.WARN)
      end
    end)
  end)
  return true
end

local function save_project_buffers(root)
  local prefix = root:sub(-1) == "/" and root or root .. "/"
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(buffer)
    if vim.bo[buffer].modified and name:sub(1, #prefix) == prefix then
      local ok, err = pcall(vim.api.nvim_buf_call, buffer, function()
        vim.cmd("silent write")
      end)
      if not ok then
        notify("Could not save project buffer: " .. tostring(err), vim.log.levels.ERROR)
        return false
      end
    end
  end
  return true
end

local function cmake_commands(project, root)
  local configure = { "cmake", "-S", root, "-B", project.build_dir, "-DCMAKE_BUILD_TYPE=" .. project.build_type }
  local build = { "cmake", "--build", project.build_dir }
  if project.target ~= "" then
    vim.list_extend(build, { "--target", project.target })
  end
  return configure, build
end

local function project_run_argv(command, root)
  local argv = copy(command)
  if argv[1] and not argv[1]:match("^/") and argv[1]:find("/", 1, true) then
    argv[1] = root .. "/" .. argv[1]:gsub("^%./", "")
  end
  return argv
end

local function canonical(path)
  local resolved = vim.uv.fs_realpath(path) or vim.fn.fnamemodify(path, ":p")
  if resolved ~= "/" then
    resolved = resolved:gsub("/+$", "")
  end
  return resolved
end

local function project_root_for_buffer()
  local source = vim.api.nvim_buf_get_name(0)
  if source == "" then return vim.fn.getcwd() end
  return vim.fs.root(source, { "CMakeLists.txt", "Makefile", ".git" }) or vim.fn.fnamemodify(source, ":h")
end

function M.run_project(skip_root_guard)
  local project = copy(settings.project)
  if project.root == "" then
    edit_project_settings(function() M.run_project(true) end, project_root_for_buffer())
    return true
  end
  local root = canonical(project.root)
  if vim.fn.isdirectory(root) == 0 then
    notify("Project root does not exist: " .. root, vim.log.levels.ERROR)
    return false
  end
  local current_root = canonical(project_root_for_buffer())
  local prefix = root:sub(-1) == "/" and root or root .. "/"
  if not skip_root_guard and current_root ~= root and current_root:sub(1, #prefix) ~= prefix then
    vim.ui.select({ "Configured root", "Configure current root" }, { prompt = "C++ project root: " }, function(choice)
      if choice == "Configured root" then
        M.run_project(true)
      elseif choice == "Configure current root" then
        edit_project_settings(function() M.run_project(true) end, current_root)
      end
    end)
    return true
  end
  if not save_project_buffers(root) then
    return false
  end
  local configure, build = nil, project.build_command
  if project.kind == "cmake" then
    configure, build = cmake_commands(project, root)
  end
  if not valid_argv(build, "Project build") then return false end
  if not valid_argv(project.run_command, "Project run") then
    return false
  end
  local function run_after_build(code, build_terminal)
    if code ~= 0 then
      notify("Project build failed; program was not run", vim.log.levels.ERROR)
      return
    end
    close_terminal(build_terminal)
    open_terminal(project_run_argv(project.run_command, root), { cwd = root }, function(run_code)
      if run_code ~= 0 then
        notify("Program exited with status " .. run_code, vim.log.levels.WARN)
      end
    end)
  end
  local function start_build()
    local build_terminal
    build_terminal = open_terminal(build, { cwd = root }, function(code)
      run_after_build(code, build_terminal)
    end)
  end
  if configure then
    local configure_terminal
    configure_terminal = open_terminal(configure, { cwd = root }, function(code)
      if code ~= 0 then
        notify("CMake configure failed; project was not built", vim.log.levels.ERROR)
        return
      end
      close_terminal(configure_terminal)
      start_build()
    end)
  else
    start_build()
  end
  return true
end

local function input(prompt, default, callback)
  vim.ui.input({ prompt = prompt, default = default }, function(value)
    if value ~= nil then
      callback(value)
    end
  end)
end

local function edit_file_settings(done)
  local draft = copy(settings)
  input("C++ compiler: ", draft.compiler, function(compiler)
    draft.compiler = compiler
    vim.ui.select({ "c++17", "c++20", "c++23" }, { prompt = "C++ standard: " }, function(standard)
      if not standard then return end
      draft.standard = standard
      input("Compiler flags (comma-separated argv): ", csv_text(draft.flags), function(flags)
        draft.flags = csv(flags)
        input("Program arguments (comma-separated argv): ", csv_text(draft.program_args), function(args)
          draft.program_args = csv(args)
          settings = draft
          save()
          notify("File runner settings saved")
          if done then done() end
        end)
      end)
    end)
  end)
end

edit_project_settings = function(done, root_default)
  local draft = copy(settings)
  local project = draft.project
  vim.ui.select({ "cmake", "make", "custom" }, { prompt = "Project build type: " }, function(kind)
    if not kind then return end
    project.kind = kind
    input("Project root: ", root_default or (project.root ~= "" and project.root or vim.fn.getcwd()), function(root)
      project.root = root
      local function finish()
        input("Run command (comma-separated argv): ", csv_text(project.run_command), function(run)
          project.run_command = csv(run)
          settings = draft
          if save() then
            notify("Project runner settings saved")
            if done then done() end
          end
        end)
      end
      if kind == "cmake" then
        input("Build directory: ", project.build_dir, function(build_dir)
          project.build_dir = build_dir
          vim.ui.select({ "Debug", "Release", "RelWithDebInfo", "MinSizeRel" }, { prompt = "CMake build type: " }, function(build_type)
            if not build_type then return end
            project.build_type = build_type
            input("CMake target (blank for default): ", project.target, function(target)
              project.target = target
              finish()
            end)
          end)
        end)
      else
        local suggested = kind == "make" and { "make" } or project.build_command
        input("Build command (comma-separated argv): ", csv_text(suggested), function(build)
          project.build_command = csv(build)
          finish()
        end)
      end
    end)
  end)
end

function M.settings()
  vim.ui.select({ "File runner", "Project runner" }, { prompt = "C++ runner settings: " }, function(choice)
    if choice == "File runner" then
      edit_file_settings()
    elseif choice == "Project runner" then
      edit_project_settings()
    end
  end)
end

function M.setup(options)
  options = options or {}
  state_path = options.state_path or (vim.fn.stdpath("state") .. "/cpp_runner.json")
  cache_path = options.cache_path or (vim.fn.stdpath("cache") .. "/cpp_runner")
  terminal = options.terminal or default_terminal
  settings = merge(load(), options.settings)
  vim.api.nvim_create_user_command("CppRunFile", M.run_file, { desc = "Compile and run current C++ file", force = true })
  vim.api.nvim_create_user_command("CppRunProject", function() M.run_project() end, { desc = "Build and run configured C++ project", force = true })
  vim.api.nvim_create_user_command("CppRunSettings", M.settings, { desc = "Configure C++ runner", force = true })
  return M
end

M._test = {
  file_argv = file_argv,
  run_argv = run_argv,
  project_run_argv = project_run_argv,
  csv = csv,
  settings = function() return copy(settings) end,
}

return M
