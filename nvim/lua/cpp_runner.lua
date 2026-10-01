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
local setup_new_project
local canonical
local default_terminal

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

local function command_available(argv, cwd)
  if terminal ~= default_terminal then return true end
  local command = argv[1]
  if command:find("/", 1, true) and not command:match("^/") then
    command = cwd .. "/" .. command:gsub("^%./", "")
  end
  if vim.fn.executable(command) == 1 then return true end
  notify("Command not found: " .. argv[1], vim.log.levels.ERROR)
  return false
end

default_terminal = function(argv, options, on_exit)
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

local function project_output_path(root)
  return output_path(root .. "/.cpp-runner-project")
end

local function source_uses_qt(path, visited, depth)
  if depth > 6 or visited[path] or vim.tbl_count(visited) >= 128 then return false end
  visited[path] = true
  local file = io.open(path, "r")
  if not file then return false end
  local content = file:read("*a") or ""
  file:close()
  if content:match("#%s*include%s*[<\"]Q[%w_]+[>\"]")
      or content:match("#%s*include%s*[<\"]Qt[%w_/]+[>\"]") then
    return true
  end
  local directory = vim.fn.fnamemodify(path, ":h")
  for header in content:gmatch("#%s*include%s*\"([^\"]+)\"") do
    local candidate = vim.uv.fs_realpath(directory .. "/" .. header)
    if candidate and source_uses_qt(candidate, visited, depth + 1) then return true end
  end
  return false
end

local function split_flags(lines)
  local result = {}
  for _, line in ipairs(lines) do
    for flag in line:gmatch("%S+") do table.insert(result, flag) end
  end
  return result
end

local function qt_flags(sources)
  local uses_qt = false
  local visited = {}
  for _, source in ipairs(sources or {}) do
    if source_uses_qt(source, visited, 0) then
      uses_qt = true
      break
    end
  end
  if not uses_qt or vim.fn.executable("pkg-config") ~= 1 then return {}, {} end
  for _, packages in ipairs({
    { "Qt6Widgets", "Qt6Gui", "Qt6Core" },
    { "Qt6Gui", "Qt6Core" },
    { "Qt5Widgets", "Qt5Gui", "Qt5Core" },
    { "Qt5Gui", "Qt5Core" },
  }) do
    local exists = { "pkg-config", "--exists" }
    vim.list_extend(exists, packages)
    vim.fn.system(exists)
    if vim.v.shell_error == 0 then
      local cflags = { "pkg-config", "--cflags" }
      local libs = { "pkg-config", "--libs" }
      vim.list_extend(cflags, packages)
      vim.list_extend(libs, packages)
      local cflag_result = vim.fn.systemlist(cflags)
      if vim.v.shell_error == 0 then
        local lib_result = vim.fn.systemlist(libs)
        if vim.v.shell_error == 0 then return split_flags(cflag_result), split_flags(lib_result) end
      end
    end
  end
  return {}, {}
end

local function file_argv(source, output, values)
  local argv = { values.compiler, "-std=" .. values.standard }
  vim.list_extend(argv, values.flags or {})
  local cflags, libs = qt_flags({ source })
  vim.list_extend(argv, cflags)
  table.insert(argv, source)
  table.insert(argv, "-o")
  table.insert(argv, output)
  vim.list_extend(argv, libs)
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
  if not command_available(compile, vim.fn.fnamemodify(source, ":h")) then return false end
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

local source_extensions = {
  cpp = true,
  cxx = true,
  cc = true,
  ["c++"] = true,
  cp = true,
}

local excluded_directories = {
  [".git"] = true,
  [".cache"] = true,
  [".idea"] = true,
  [".vscode"] = true,
  ["node_modules"] = true,
  ["third_party"] = true,
  ["third-party"] = true,
  ["vendor"] = true,
  ["external"] = true,
}

local function project_sources(root, build_dir)
  local sources = {}
  local max_sources = 200
  local max_depth = 8
  local max_entries = 5000
  local entries = 0
  local limit_error
  local absolute_build = canonical(root .. "/" .. build_dir)

  local function scan(directory, depth)
    if depth > max_depth then return true end
    local handle = vim.uv.fs_scandir(directory)
    if not handle then return true end
    while true do
      local name, kind = vim.uv.fs_scandir_next(handle)
      if not name then break end
      entries = entries + 1
      if entries > max_entries then
        limit_error = "g++ project scan exceeded " .. max_entries .. " files and directories"
        return false
      end
      local path = directory .. "/" .. name
      if kind == "directory" then
        local absolute = canonical(path)
        local generated = name == "build" or name:match("^cmake%-build%-")
        local hidden = name:sub(1, 1) == "."
        if not hidden and not excluded_directories[name] and not generated and absolute ~= absolute_build then
          if not scan(path, depth + 1) then return false end
        end
      elseif kind == "file" then
        local extension = vim.fn.fnamemodify(name, ":e"):lower()
        if source_extensions[extension] then
          table.insert(sources, path)
          if #sources > max_sources then
            limit_error = "g++ project has more than " .. max_sources .. " C++ source files"
            return false
          end
        end
      end
    end
    return true
  end

  if not scan(root, 0) then
    return nil, limit_error or "Could not scan g++ project sources"
  end
  table.sort(sources)
  if #sources == 0 then
    return nil, "No C++ source files found under project root"
  end
  return sources
end

local function strip_cpp_comments_and_literals(content)
  local result = {}
  local state = "code"
  local index = 1
  while index <= #content do
    local char = content:sub(index, index)
    local next_char = content:sub(index + 1, index + 1)
    if state == "code" then
      if char == "/" and next_char == "/" then
        state = "line_comment"
        index = index + 2
      elseif char == "/" and next_char == "*" then
        state = "block_comment"
        index = index + 2
      elseif char == '"' then
        state = "string"
        table.insert(result, " ")
        index = index + 1
      elseif char == "'" then
        state = "character"
        table.insert(result, " ")
        index = index + 1
      else
        table.insert(result, char)
        index = index + 1
      end
    elseif state == "line_comment" then
      if char == "\n" then
        table.insert(result, char)
        state = "code"
      end
      index = index + 1
    elseif state == "block_comment" then
      if char == "*" and next_char == "/" then
        state = "code"
        index = index + 2
      else
        if char == "\n" then table.insert(result, char) end
        index = index + 1
      end
    else
      if char == "\\" then
        index = index + 2
      elseif (state == "string" and char == '"') or (state == "character" and char == "'") then
        state = "code"
        index = index + 1
      else
        if char == "\n" then table.insert(result, char) end
        index = index + 1
      end
    end
  end
  return table.concat(result)
end

local function source_has_main(path)
  local file = io.open(path, "r")
  if not file then return false end
  local content = file:read("*a")
  file:close()
  content = strip_cpp_comments_and_literals(content)
  return content:find("%f[%w_]int%s+main%s*%b()%s*{") ~= nil
end

local function gpp_command(project, root, values)
  local sources, err = project_sources(root, project.build_dir)
  if not sources then return nil, nil, err end
  local current = canonical(vim.api.nvim_buf_get_name(0))
  local mains = {}
  for _, source in ipairs(sources) do
    if source_has_main(source) then table.insert(mains, canonical(source)) end
  end
  if #mains > 1 then
    if not vim.tbl_contains(mains, current) then
      return nil, nil, "Multiple C++ entry points found; open the one to run"
    end
    sources = vim.tbl_filter(function(source)
      local absolute = canonical(source)
      return absolute == current or not vim.tbl_contains(mains, absolute)
    end, sources)
  end
  local output = project_output_path(root)
  local argv = { values.compiler, "-std=" .. values.standard }
  vim.list_extend(argv, values.flags or {})
  local cflags, libs = qt_flags(sources)
  vim.list_extend(argv, cflags)
  vim.list_extend(argv, sources)
  vim.list_extend(argv, { "-o", output })
  vim.list_extend(argv, libs)
  return argv, run_argv(output, values)
end

local function project_run_argv(command, root)
  local argv = copy(command)
  if argv[1] and not argv[1]:match("^/") and argv[1]:find("/", 1, true) then
    argv[1] = root .. "/" .. argv[1]:gsub("^%./", "")
  end
  return argv
end

canonical = function(path)
  local resolved = vim.uv.fs_realpath(path) or vim.fn.fnamemodify(path, ":p")
  if resolved ~= "/" then
    resolved = resolved:gsub("/+$", "")
  end
  return resolved
end

local function project_root_for_buffer()
  local source = vim.api.nvim_buf_get_name(0)
  if source == "" then return vim.fn.getcwd() end
  local marked = vim.fs.root(source, { "CMakeLists.txt", "Makefile" })
  local directory = vim.fn.fnamemodify(source, ":h")
  local cursor = directory
  for _ = 1, 3 do
    if vim.fn.fnamemodify(cursor, ":t") == "src" then
      local source_root = vim.fn.fnamemodify(cursor, ":h")
      if not marked or #source_root > #marked then return source_root end
      break
    end
    local parent = vim.fn.fnamemodify(cursor, ":h")
    if parent == cursor then break end
    cursor = parent
  end
  return marked or directory
end

function M.run_project(skip_root_guard)
  local project = copy(settings.project)
  if project.root == "" then
    setup_new_project(function() M.run_project(true) end, project_root_for_buffer())
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
  local run = project.run_command
  local inferred_cmake_run = false
  if project.kind == "cmake" then
    configure, build = cmake_commands(project, root)
    if #run == 0 and project.target ~= "" then
      run = { project.build_dir .. "/" .. project.target }
      inferred_cmake_run = true
    end
  elseif project.kind == "g++" then
    local err
    build, run, err = gpp_command(project, root, settings)
    if err then
      notify(err, vim.log.levels.ERROR)
      return false
    end
  end
  if not valid_argv(build, "Project build") then return false end
  if not command_available(build, root) then return false end
  if not valid_argv(run, "Project run") then
    return false
  end
  local function run_after_build(code, build_terminal)
    if code ~= 0 then
      notify("Project build failed; program was not run", vim.log.levels.ERROR)
      return
    end
    close_terminal(build_terminal)
    local run_command = project_run_argv(run, root)
    if inferred_cmake_run and vim.fn.executable(run_command[1]) == 0 then
      notify("CMake target output not found at " .. run_command[1] .. "; set Run command in C++ Run Settings", vim.log.levels.ERROR)
      return
    end
    open_terminal(run_command, { cwd = root }, function(run_code)
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

local function cmake_targets(root)
  local file = io.open(root .. "/CMakeLists.txt", "r")
  if not file then return {} end
  local content = file:read("*a")
  file:close()
  local targets = {}
  local seen = {}
  for target in content:gmatch("add_executable%s*%(%s*([%w_.+%-]+)") do
    if not seen[target] then
      seen[target] = true
      table.insert(targets, target)
    end
  end
  return targets
end

local function save_project_draft(draft, done, message)
  settings = draft
  if save() then
    notify(message or "Project runner settings saved")
    if done then done() end
  end
end

setup_new_project = function(done, root_default)
  local root = canonical(root_default)
  local has_cmake = vim.fn.filereadable(root .. "/CMakeLists.txt") == 1
  local cmake_label = "CMake (creates build/ automatically)"
  local gpp_label = "g++ (no build directory)"
  local choices = has_cmake and { cmake_label, gpp_label } or { gpp_label, cmake_label }
  vim.ui.select(choices, { prompt = "Run C++ project with: " }, function(choice)
    if not choice then return end
    local draft = copy(settings)
    draft.project.root = root
    draft.project.kind = choice == gpp_label and "g++" or "cmake"
    draft.project.run_command = {}
    if draft.project.kind == "g++" then
      save_project_draft(draft, done, "g++ project runner saved")
      return
    end
    local targets = cmake_targets(root)
    if #targets == 1 then
      draft.project.target = targets[1]
      save_project_draft(draft, done, "CMake project saved; build/ will be created automatically")
      return
    end
    input("CMake executable target: ", draft.project.target, function(target)
      draft.project.target = target
      save_project_draft(draft, done, "CMake project saved; build/ will be created automatically")
    end)
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
  vim.ui.select({ "cmake", "g++", "make", "custom" }, { prompt = "Project build type: " }, function(kind)
    if not kind then return end
    project.kind = kind
    input("Project root: ", root_default or (project.root ~= "" and project.root or vim.fn.getcwd()), function(root)
      project.root = root
      local function finish(prompt)
        input(prompt or "Run command (comma-separated argv): ", csv_text(project.run_command), function(run)
          project.run_command = csv(run)
          save_project_draft(draft, done)
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
              finish("Run command (comma-separated argv; blank uses target): ")
            end)
          end)
        end)
      elseif kind == "g++" then
        project.run_command = {}
        save_project_draft(draft, done)
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
