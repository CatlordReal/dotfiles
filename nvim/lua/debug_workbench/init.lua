local M = {}

local state = {
    resource_buf = nil,
    resource_win = nil,
    resource_timer = nil,
    resource_interval_ms = 1000,
    pid = nil,
    process_name = nil,
    current_sample = nil,
    logging = false,
    log_file = nil,
    terminal_buf = nil,
    terminal_win = nil,
    terminal_config = nil,
}

local function notify(message, level)
    vim.notify("[Debug] " .. message, level or vim.log.levels.INFO)
end

local function ui_size()
    local ui = vim.api.nvim_list_uis()[1]
    return ui or { width = vim.o.columns, height = vim.o.lines }
end

local function clamp(value, min_value, max_value)
    return math.max(min_value, math.min(max_value, value))
end

local function workbench_dir()
    local dir = vim.fs.joinpath(vim.fn.stdpath("state"), "debug-workbench")
    vim.fn.mkdir(dir, "p")
    return dir
end

local function timestamp()
    return os.date("%Y-%m-%d %H:%M:%S")
end

local function filename_timestamp()
    return os.date("%Y%m%d-%H%M%S")
end

local function csv(value)
    local text = tostring(value or "")
    if text:find('[,"\n]') then
        return '"' .. text:gsub('"', '""') .. '"'
    end
    return text
end

local function split_args(input)
    input = tostring(input or "")
    local args = {}
    local current = {}
    local quote = nil
    local escaped = false

    for index = 1, #input do
        local char = input:sub(index, index)
        if escaped then
            table.insert(current, char)
            escaped = false
        elseif char == "\\" then
            escaped = true
        elseif quote then
            if char == quote then
                quote = nil
            else
                table.insert(current, char)
            end
        elseif char == '"' or char == "'" then
            quote = char
        elseif char:match("%s") then
            if #current > 0 then
                table.insert(args, table.concat(current))
                current = {}
            end
        else
            table.insert(current, char)
        end
    end

    if #current > 0 then
        table.insert(args, table.concat(current))
    end

    return args
end

local function command_args_prompt()
    return split_args(vim.fn.input("Arguments: "))
end

local function executable(name)
    local path = vim.fn.exepath(name)
    if path and path ~= "" then
        return path
    end

    local mason_path = vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "bin", name)
    if vim.fn.executable(mason_path) == 1 then
        return mason_path
    end

    return name
end

local function find_dotnet_dlls()
    local dlls = vim.fn.globpath(vim.fn.getcwd(), "**/bin/Debug/**/*.dll", false, true)
    local filtered = {}
    local seen = {}

    for _, dll in ipairs(dlls) do
        local normalized = vim.fs.normalize(dll)
        if not normalized:find("/obj/", 1, true)
            and not normalized:find("/ref/", 1, true)
            and not seen[normalized]
        then
            table.insert(filtered, normalized)
            seen[normalized] = true
        end
    end

    table.sort(filtered)
    return filtered
end

local function pick_dotnet_dll()
    local dlls = find_dotnet_dlls()
    local default = dlls[1] or (vim.fn.getcwd() .. "/bin/Debug/")
    return vim.fn.input("Path to .NET dll: ", default, "file")
end

local function find_default_executable()
    local cwd = vim.fn.getcwd()
    local dirs = {
        vim.fs.joinpath(cwd, "build"),
        vim.fs.joinpath(cwd, "cmake-build-debug"),
        vim.fs.joinpath(cwd, "bin", "Debug"),
        vim.fs.joinpath(cwd, "Debug"),
    }

    for _, dir in ipairs(dirs) do
        if vim.fn.isdirectory(dir) == 1 then
            local candidates = vim.fn.globpath(dir, "*", false, true)
            table.sort(candidates)
            for _, candidate in ipairs(candidates) do
                if vim.fn.isdirectory(candidate) == 0 and vim.fn.executable(candidate) == 1 then
                    return candidate
                end
            end
        end
    end

    return cwd .. "/"
end

local function pick_executable()
    return vim.fn.input("Path to executable: ", find_default_executable(), "file")
end

local function pick_process_id()
    local pid = require("dap.utils").pick_process()
    if pid and pid ~= require("dap").ABORT then
        M.set_resource_pid(pid)
    end
    return pid
end

local function adapter_health()
    local codelldb_path = executable("codelldb")
    local netcoredbg_path = executable("netcoredbg")
    local lines = { "Debug adapter health" }
    local level = vim.log.levels.INFO

    if vim.fn.executable(codelldb_path) == 1 then
        table.insert(lines, "codelldb: ready (" .. codelldb_path .. ")")
    else
        table.insert(lines, "codelldb: missing; install with :MasonInstall codelldb")
        level = vim.log.levels.WARN
    end

    if vim.fn.executable(netcoredbg_path) ~= 1 then
        table.insert(lines, "netcoredbg: missing; install with :MasonInstall netcoredbg")
        level = vim.log.levels.WARN
        return lines, level
    end

    local output = vim.fn.systemlist({ netcoredbg_path, "--version" })
    if vim.v.shell_error == 0 then
        table.insert(lines, "netcoredbg: ready (" .. netcoredbg_path .. ")")
    else
        local text = table.concat(output or {}, " ")
        if text:match("Bad CPU type") then
            table.insert(lines, "netcoredbg: installed but not runnable on this CPU without Rosetta (" .. netcoredbg_path .. ")")
        else
            table.insert(lines, "netcoredbg: installed but failed health check (" .. netcoredbg_path .. ")")
            if text ~= "" then
                table.insert(lines, "  " .. text)
            end
        end
        level = vim.log.levels.WARN
    end

    return lines, level
end

local function format_mb(kb)
    return string.format("%.1f MB", (tonumber(kb) or 0) / 1024)
end

local function ps_command()
    if vim.loop.os_uname().sysname == "Darwin" then
        return { "ps", "-axo", "pid=,ppid=,pcpu=,pmem=,rss=,vsz=,state=,etime=,comm=" }
    end
    return { "ps", "-eo", "pid=,ppid=,pcpu=,pmem=,rss=,vsz=,stat=,etime=,comm=" }
end

local function read_process_table()
    local lines = vim.fn.systemlist(ps_command())
    if vim.v.shell_error ~= 0 then
        return nil, table.concat(lines, "\n")
    end

    local rows = {}
    local by_pid = {}
    local children = {}

    for _, line in ipairs(lines) do
        local pid, ppid, pcpu, pmem, rss, vsz, state_text, elapsed, command = line:match(
            "^%s*(%d+)%s+(%d+)%s+([%d%.]+)%s+([%d%.]+)%s+(%d+)%s+(%d+)%s+(%S+)%s+(%S+)%s+(.+)$"
        )
        if pid then
            local row = {
                pid = tonumber(pid),
                ppid = tonumber(ppid),
                cpu = tonumber(pcpu) or 0,
                mem_percent = tonumber(pmem) or 0,
                rss_kb = tonumber(rss) or 0,
                vsz_kb = tonumber(vsz) or 0,
                state = state_text,
                elapsed = elapsed,
                command = command,
            }
            table.insert(rows, row)
            by_pid[row.pid] = row
            children[row.ppid] = children[row.ppid] or {}
            table.insert(children[row.ppid], row)
        end
    end

    return {
        rows = rows,
        by_pid = by_pid,
        children = children,
    }
end

local function thread_count(pid)
    if not pid then
        return nil
    end

    for _, field in ipairs({ "thcount=", "nlwp=" }) do
        local out = vim.fn.systemlist({ "ps", "-p", tostring(pid), "-o", field })
        if vim.v.shell_error == 0 and out[1] then
            local count = tonumber(vim.trim(out[1]))
            if count then
                return count
            end
        end
    end

    return nil
end

local function collect_sample(pid)
    if not pid then
        return {
            status = "waiting",
            timestamp = timestamp(),
            error = "Waiting for the debug adapter to report a process ID.",
        }
    end

    local table_data, err = read_process_table()
    if not table_data then
        return {
            status = "unavailable",
            timestamp = timestamp(),
            pid = pid,
            name = state.process_name,
            error = err ~= "" and err or "Unable to read process table.",
        }
    end

    local root = table_data.by_pid[pid]
    if not root then
        return {
            status = "exited",
            timestamp = timestamp(),
            pid = pid,
            name = state.process_name,
            error = "Process is not present in ps output.",
        }
    end

    local processes = {}
    local totals = {
        cpu = 0,
        mem_percent = 0,
        rss_kb = 0,
        vsz_kb = 0,
    }
    local visited = {}

    local function add_process(process)
        if not process or visited[process.pid] then
            return
        end
        visited[process.pid] = true
        table.insert(processes, process)
        totals.cpu = totals.cpu + process.cpu
        totals.mem_percent = totals.mem_percent + process.mem_percent
        totals.rss_kb = totals.rss_kb + process.rss_kb
        totals.vsz_kb = totals.vsz_kb + process.vsz_kb

        for _, child in ipairs(table_data.children[process.pid] or {}) do
            add_process(child)
        end
    end

    add_process(root)
    table.sort(processes, function(a, b)
        return a.pid < b.pid
    end)

    return {
        status = "running",
        timestamp = timestamp(),
        pid = pid,
        name = state.process_name or root.command,
        root = root,
        processes = processes,
        process_count = #processes,
        totals = totals,
        threads = thread_count(pid),
    }
end

local function render_resource_lines(sample)
    local lines = {
        "Debug Resources",
        "===============",
        "",
    }

    if sample.status == "waiting" then
        table.insert(lines, sample.error)
        table.insert(lines, "")
        table.insert(lines, "p  set PID manually")
        table.insert(lines, "l  toggle CSV logging")
        table.insert(lines, "s  snapshot current reading")
        table.insert(lines, "q  close panel")
        return lines
    end

    table.insert(lines, "PID: " .. tostring(sample.pid))
    if sample.name and sample.name ~= "" then
        table.insert(lines, "Name: " .. sample.name)
    end
    table.insert(lines, "Status: " .. sample.status)
    table.insert(lines, "Updated: " .. sample.timestamp)

    if sample.status ~= "running" then
        table.insert(lines, "")
        table.insert(lines, sample.error or "No live process data.")
        table.insert(lines, "")
        table.insert(lines, "p  set PID manually")
        table.insert(lines, "l  toggle CSV logging")
        table.insert(lines, "s  write snapshot")
        table.insert(lines, "q  close panel")
        return lines
    end

    table.insert(lines, "")
    table.insert(lines, "Aggregate")
    table.insert(lines, "---------")
    table.insert(lines, string.format("CPU: %.1f%%", sample.totals.cpu))
    table.insert(lines, string.format("Memory: %s RSS / %s VSZ", format_mb(sample.totals.rss_kb), format_mb(sample.totals.vsz_kb)))
    table.insert(lines, string.format("Memory %%: %.1f%%", sample.totals.mem_percent))
    table.insert(lines, "Processes: " .. tostring(sample.process_count))
    table.insert(lines, "Threads: " .. tostring(sample.threads or "n/a"))
    table.insert(lines, "Elapsed: " .. tostring((sample.root or {}).elapsed or "n/a"))
    table.insert(lines, "State: " .. tostring((sample.root or {}).state or "n/a"))
    table.insert(lines, "")
    table.insert(lines, "Logging")
    table.insert(lines, "-------")
    table.insert(lines, state.logging and "On" or "Off")
    if state.log_file then
        table.insert(lines, state.log_file)
    end
    table.insert(lines, "")
    table.insert(lines, "Process Tree")
    table.insert(lines, "------------")

    for _, process in ipairs(sample.processes or {}) do
        table.insert(lines, string.format(
            "%6d  cpu %5.1f  rss %8s  %s",
            process.pid,
            process.cpu,
            format_mb(process.rss_kb),
            process.command
        ))
    end

    table.insert(lines, "")
    table.insert(lines, "Keys: l log, s snapshot, p pid, r refresh, q close")

    return lines
end

local function append_log(sample)
    if not state.logging or not state.log_file or sample.status ~= "running" then
        return
    end

    local row = table.concat({
        csv(sample.timestamp),
        csv(sample.pid),
        csv(sample.name or ""),
        csv(sample.process_count or 0),
        csv(string.format("%.1f", sample.totals.cpu)),
        csv(string.format("%.1f", sample.totals.mem_percent)),
        csv(string.format("%.1f", (sample.totals.rss_kb or 0) / 1024)),
        csv(string.format("%.1f", (sample.totals.vsz_kb or 0) / 1024)),
        csv(sample.threads or ""),
        csv((sample.root or {}).state or ""),
        csv((sample.root or {}).elapsed or ""),
    }, ",")

    vim.fn.writefile({ row }, state.log_file, "a")
end

local function update_resource_buffer(sample)
    if not state.resource_buf or not vim.api.nvim_buf_is_valid(state.resource_buf) then
        return
    end

    vim.bo[state.resource_buf].modifiable = true
    vim.api.nvim_buf_set_lines(state.resource_buf, 0, -1, false, render_resource_lines(sample))
    vim.bo[state.resource_buf].modified = false
    vim.bo[state.resource_buf].modifiable = false
end

function M.refresh_resources()
    state.current_sample = collect_sample(state.pid)
    append_log(state.current_sample)
    update_resource_buffer(state.current_sample)
    return state.current_sample
end

local function stop_resource_timer_if_idle()
    if state.resource_timer
        and not state.logging
        and (not state.resource_win or not vim.api.nvim_win_is_valid(state.resource_win))
    then
        state.resource_timer:stop()
        state.resource_timer:close()
        state.resource_timer = nil
    end
end

local function ensure_resource_timer()
    if state.resource_timer then
        return
    end

    state.resource_timer = vim.uv.new_timer()
    if not state.resource_timer then
        return
    end

    state.resource_timer:start(0, state.resource_interval_ms, vim.schedule_wrap(function()
        M.refresh_resources()
        stop_resource_timer_if_idle()
    end))
    pcall(state.resource_timer.unref, state.resource_timer)
end

local function configure_resource_buffer(buf)
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = "debug-resources"

    local opts = { buffer = buf, silent = true, nowait = true }
    vim.keymap.set("n", "q", M.close_resource_panel, opts)
    vim.keymap.set("n", "r", M.refresh_resources, opts)
    vim.keymap.set("n", "l", M.toggle_resource_log, opts)
    vim.keymap.set("n", "s", M.take_resource_snapshot, opts)
    vim.keymap.set("n", "p", M.prompt_resource_pid, opts)
end

function M.open_resource_panel(opts)
    opts = opts or {}

    if state.resource_win and vim.api.nvim_win_is_valid(state.resource_win) then
        if opts.focus then
            vim.api.nvim_set_current_win(state.resource_win)
        end
        ensure_resource_timer()
        M.refresh_resources()
        return
    end

    if not state.resource_buf or not vim.api.nvim_buf_is_valid(state.resource_buf) then
        state.resource_buf = vim.api.nvim_create_buf(false, true)
        configure_resource_buffer(state.resource_buf)
    end

    local previous_win = vim.api.nvim_get_current_win()
    local width = clamp(math.floor(vim.o.columns * 0.24), 34, 52)
    vim.cmd("botright vertical " .. width .. "new")
    state.resource_win = vim.api.nvim_get_current_win()
    local scratch = vim.api.nvim_get_current_buf()
    vim.api.nvim_win_set_buf(state.resource_win, state.resource_buf)
    if scratch ~= state.resource_buf and vim.api.nvim_buf_is_valid(scratch) then
        pcall(vim.api.nvim_buf_delete, scratch, { force = true })
    end

    vim.wo[state.resource_win].number = false
    vim.wo[state.resource_win].relativenumber = false
    vim.wo[state.resource_win].signcolumn = "no"
    vim.wo[state.resource_win].cursorline = true
    vim.wo[state.resource_win].winfixwidth = true
    vim.wo[state.resource_win].wrap = false

    ensure_resource_timer()
    M.refresh_resources()

    if not opts.focus and previous_win and vim.api.nvim_win_is_valid(previous_win) then
        vim.api.nvim_set_current_win(previous_win)
    end
end

function M.close_resource_panel()
    if state.resource_win and vim.api.nvim_win_is_valid(state.resource_win) then
        vim.api.nvim_win_close(state.resource_win, true)
    end
    state.resource_win = nil
    stop_resource_timer_if_idle()
end

function M.toggle_resource_panel()
    if state.resource_win and vim.api.nvim_win_is_valid(state.resource_win) then
        M.close_resource_panel()
    else
        M.open_resource_panel({ focus = true })
    end
end

function M.set_resource_pid(pid, process_name, opts)
    opts = opts or {}
    local number = tonumber(pid)
    if not number then
        return
    end

    state.pid = number
    if process_name and process_name ~= "" then
        state.process_name = process_name
    end
    ensure_resource_timer()
    M.refresh_resources()

    if not opts.quiet then
        notify("Monitoring PID " .. tostring(number))
    end
end

function M.prompt_resource_pid()
    vim.ui.input({
        prompt = "Debug process PID: ",
        default = state.pid and tostring(state.pid) or "",
    }, function(input)
        if not input or input == "" then
            return
        end
        M.set_resource_pid(input)
    end)
end

function M.toggle_resource_log()
    if state.logging then
        state.logging = false
        notify("Resource logging stopped")
        stop_resource_timer_if_idle()
        M.refresh_resources()
        return
    end

    state.log_file = vim.fs.joinpath(workbench_dir(), "resource-log-" .. filename_timestamp() .. ".csv")
    vim.fn.writefile({
        "timestamp,pid,name,processes,cpu_percent,mem_percent,rss_mb,vsz_mb,threads,state,elapsed",
    }, state.log_file)
    state.logging = true
    ensure_resource_timer()
    M.refresh_resources()
    notify("Resource logging to " .. state.log_file)
end

local function snapshot_lines(sample)
    local lines = render_resource_lines(sample)
    table.insert(lines, 1, "# Debug Resource Snapshot")
    table.insert(lines, 2, "")
    return lines
end

function M.take_resource_snapshot()
    local sample = M.refresh_resources()
    local path = vim.fs.joinpath(workbench_dir(), "resource-snapshot-" .. filename_timestamp() .. ".md")
    vim.fn.writefile(snapshot_lines(sample), path)
    notify("Resource snapshot written to " .. path)
    return path
end

local function default_terminal_config()
    local ui = ui_size()
    local width = clamp(math.floor(ui.width * 0.72), 64, math.max(64, ui.width - 4))
    local height = clamp(math.floor(ui.height * 0.34), 12, math.max(12, ui.height - 6))
    return {
        relative = "editor",
        style = "minimal",
        border = "rounded",
        title = " Debug Terminal ",
        title_pos = "center",
        width = width,
        height = height,
        row = clamp(ui.height - height - 4, 1, math.max(1, ui.height - height - 2)),
        col = clamp(math.floor((ui.width - width) / 2), 0, math.max(0, ui.width - width)),
    }
end

local function clamp_terminal_config(config)
    local ui = ui_size()
    config.width = clamp(math.floor(tonumber(config.width) or 80), 40, math.max(40, ui.width - 4))
    config.height = clamp(math.floor(tonumber(config.height) or 16), 8, math.max(8, ui.height - 6))
    config.row = clamp(math.floor(tonumber(config.row) or 1), 0, math.max(0, ui.height - config.height - 2))
    config.col = clamp(math.floor(tonumber(config.col) or 1), 0, math.max(0, ui.width - config.width))
    config.relative = "editor"
    config.style = "minimal"
    config.border = "rounded"
    config.title = " Debug Terminal "
    config.title_pos = "center"
    return config
end

local function terminal_window_options(win)
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "no"
    vim.wo[win].winblend = 0
end

local function update_terminal_window(updates)
    if not state.terminal_win or not vim.api.nvim_win_is_valid(state.terminal_win) then
        return
    end

    local config = vim.api.nvim_win_get_config(state.terminal_win)
    config.row = (tonumber(config.row) or 0) + (updates.row or 0)
    config.col = (tonumber(config.col) or 0) + (updates.col or 0)
    config.width = (tonumber(config.width) or 80) + (updates.width or 0)
    config.height = (tonumber(config.height) or 16) + (updates.height or 0)
    config = clamp_terminal_config(config)
    state.terminal_config = vim.deepcopy(config)
    vim.api.nvim_win_set_config(state.terminal_win, config)
end

local function configure_terminal_buffer(buf)
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = "dap-terminal"

    local normal_opts = { buffer = buf, silent = true, nowait = true }
    vim.keymap.set("n", "q", M.close_terminal, normal_opts)
    vim.keymap.set("n", "<leader>dm", M.terminal_resize_mode, normal_opts)
    vim.keymap.set("n", "<C-h>", function() update_terminal_window({ col = -4 }) end, normal_opts)
    vim.keymap.set("n", "<C-j>", function() update_terminal_window({ row = 2 }) end, normal_opts)
    vim.keymap.set("n", "<C-k>", function() update_terminal_window({ row = -2 }) end, normal_opts)
    vim.keymap.set("n", "<C-l>", function() update_terminal_window({ col = 4 }) end, normal_opts)
    vim.keymap.set("n", "<M-h>", function() update_terminal_window({ width = -4 }) end, normal_opts)
    vim.keymap.set("n", "<M-j>", function() update_terminal_window({ height = 2 }) end, normal_opts)
    vim.keymap.set("n", "<M-k>", function() update_terminal_window({ height = -2 }) end, normal_opts)
    vim.keymap.set("n", "<M-l>", function() update_terminal_window({ width = 4 }) end, normal_opts)

    local terminal_opts = { buffer = buf, silent = true, nowait = true }
    local function terminal_update(updates)
        return function()
            vim.cmd("stopinsert")
            update_terminal_window(updates)
            vim.cmd("startinsert")
        end
    end

    vim.keymap.set("t", "<M-h>", terminal_update({ width = -4 }), terminal_opts)
    vim.keymap.set("t", "<M-j>", terminal_update({ height = 2 }), terminal_opts)
    vim.keymap.set("t", "<M-k>", terminal_update({ height = -2 }), terminal_opts)
    vim.keymap.set("t", "<M-l>", terminal_update({ width = 4 }), terminal_opts)
    vim.keymap.set("t", "<M-m>", function()
        vim.cmd("stopinsert")
        M.terminal_resize_mode()
        if state.terminal_win and vim.api.nvim_win_is_valid(state.terminal_win) then
            vim.cmd("startinsert")
        end
    end, terminal_opts)
end

local function open_terminal_float(buf, focus)
    local config = clamp_terminal_config(vim.deepcopy(state.terminal_config or default_terminal_config()))
    local win = vim.api.nvim_open_win(buf, focus == true, config)
    state.terminal_win = win
    state.terminal_config = vim.deepcopy(config)
    terminal_window_options(win)
    return buf, win
end

function M.terminal_win_cmd()
    local buf = vim.api.nvim_create_buf(false, true)
    state.terminal_buf = buf
    configure_terminal_buffer(buf)
    return open_terminal_float(buf, false)
end

function M.toggle_terminal()
    if state.terminal_win and vim.api.nvim_win_is_valid(state.terminal_win) then
        vim.api.nvim_win_close(state.terminal_win, true)
        state.terminal_win = nil
        return
    end

    if not state.terminal_buf or not vim.api.nvim_buf_is_valid(state.terminal_buf) then
        notify("No debug terminal has been created for this session yet", vim.log.levels.WARN)
        return
    end

    open_terminal_float(state.terminal_buf, true)
end

function M.close_terminal()
    if state.terminal_win and vim.api.nvim_win_is_valid(state.terminal_win) then
        vim.api.nvim_win_close(state.terminal_win, true)
    end
    state.terminal_win = nil
end

function M.terminal_resize_mode()
    if not state.terminal_win or not vim.api.nvim_win_is_valid(state.terminal_win) then
        M.toggle_terminal()
    end
    local win = state.terminal_win
    if not win or not vim.api.nvim_win_is_valid(win) then
        return
    end

    notify("Terminal move mode: h/j/k/l move, H/J/K/L resize, q or Esc exits")
    while vim.api.nvim_win_is_valid(win) do
        local key = vim.fn.getcharstr()
        if key == "q" or key == "\27" then
            break
        elseif key == "h" then
            update_terminal_window({ col = -4 })
        elseif key == "j" then
            update_terminal_window({ row = 2 })
        elseif key == "k" then
            update_terminal_window({ row = -2 })
        elseif key == "l" then
            update_terminal_window({ col = 4 })
        elseif key == "H" then
            update_terminal_window({ width = -4 })
        elseif key == "J" then
            update_terminal_window({ height = 2 })
        elseif key == "K" then
            update_terminal_window({ height = -2 })
        elseif key == "L" then
            update_terminal_window({ width = 4 })
        end
    end
end

function M.dapui_config()
    return {
        layouts = {
            {
                elements = {
                    { id = "stacks", size = 0.32 },
                    { id = "scopes", size = 0.34 },
                    { id = "watches", size = 0.18 },
                    { id = "breakpoints", size = 0.16 },
                },
                size = 14,
                position = "bottom",
            },
        },
        floating = {
            border = "rounded",
            mappings = {
                close = { "q", "<Esc>" },
            },
        },
        controls = {
            enabled = vim.fn.exists("+winbar") == 1,
            element = "stacks",
            icons = {
                pause = "Pause",
                play = "Run",
                step_into = "Into",
                step_over = "Over",
                step_out = "Out",
                step_back = "Back",
                run_last = "Last",
                terminate = "Stop",
                disconnect = "Disc",
            },
        },
    }
end

function M.open_workbench()
    local ok, dapui = pcall(require, "dapui")
    if ok then
        dapui.open({ reset = true })
    end
    M.open_resource_panel({ focus = false })
end

function M.close_workbench()
    local ok, dapui = pcall(require, "dapui")
    if ok then
        dapui.close()
    end
    M.close_resource_panel()
end

function M.toggle_workbench()
    if state.resource_win and vim.api.nvim_win_is_valid(state.resource_win) then
        M.close_workbench()
    else
        M.open_workbench()
    end
end

function M.on_session_end()
    if state.logging then
        state.logging = false
        notify("Resource logging stopped; debug session ended")
    end
    M.refresh_resources()
    stop_resource_timer_if_idle()
    M.close_workbench()
end

function M.setup_adapters(dap)
    dap.adapters.codelldb = {
        type = "server",
        port = "${port}",
        executable = {
            command = executable("codelldb"),
            args = { "--port", "${port}" },
        },
    }

    dap.configurations.cpp = {
        {
            name = "Launch executable (codelldb)",
            type = "codelldb",
            request = "launch",
            program = pick_executable,
            args = command_args_prompt,
            cwd = "${workspaceFolder}",
            stopOnEntry = false,
            terminal = "integrated",
        },
        {
            name = "Attach to process (codelldb)",
            type = "codelldb",
            request = "attach",
            pid = pick_process_id,
            cwd = "${workspaceFolder}",
        },
    }
    dap.configurations.c = dap.configurations.cpp

    dap.adapters.coreclr = {
        type = "executable",
        command = executable("netcoredbg"),
        args = { "--interpreter=vscode" },
    }

    dap.configurations.cs = {
        {
            name = "Launch .NET DLL (netcoredbg)",
            type = "coreclr",
            request = "launch",
            program = pick_dotnet_dll,
            args = command_args_prompt,
            cwd = "${workspaceFolder}",
            stopAtEntry = false,
            console = "integratedTerminal",
        },
        {
            name = "Attach to .NET process (netcoredbg)",
            type = "coreclr",
            request = "attach",
            processId = pick_process_id,
        },
    }

    vim.fn.sign_define("DapBreakpoint", {
        text = "●",
        texthl = "DiagnosticError",
        linehl = "",
        numhl = "",
    })
    vim.fn.sign_define("DapBreakpointCondition", {
        text = "●",
        texthl = "DiagnosticWarn",
        linehl = "",
        numhl = "",
    })
    vim.fn.sign_define("DapLogPoint", {
        text = "◆",
        texthl = "DiagnosticInfo",
        linehl = "",
        numhl = "",
    })
    vim.fn.sign_define("DapStopped", {
        text = "▶",
        texthl = "DiagnosticInfo",
        linehl = "Visual",
        numhl = "DiagnosticInfo",
    })
end

local function define_command(name, callback, desc)
    pcall(vim.api.nvim_del_user_command, name)
    vim.api.nvim_create_user_command(name, callback, { desc = desc })
end

function M.setup_commands()
    define_command("DebugWorkbenchOpen", M.open_workbench, "Open debug workbench")
    define_command("DebugWorkbenchClose", M.close_workbench, "Close debug workbench")
    define_command("DebugWorkbenchToggle", M.toggle_workbench, "Toggle debug workbench")
    define_command("DebugAdapterHealth", M.check_adapters, "Check debug adapter availability")
    define_command("DebugResourcePanel", M.toggle_resource_panel, "Toggle debug resource panel")
    define_command("DebugResourceLogToggle", M.toggle_resource_log, "Toggle debug resource CSV logging")
    define_command("DebugResourceSnapshot", M.take_resource_snapshot, "Write debug resource snapshot")
    define_command("DebugResourcePid", M.prompt_resource_pid, "Set debug resource monitor PID")
    define_command("DebugTerminalToggle", M.toggle_terminal, "Toggle debug terminal float")
    define_command("DebugTerminalResizeMode", M.terminal_resize_mode, "Move or resize debug terminal")
end

function M.setup(dap)
    M.setup_commands()
    dap.defaults.fallback.terminal_win_cmd = M.terminal_win_cmd
    dap.defaults.fallback.focus_terminal = false

    dap.listeners.after.event_initialized["debug_workbench"] = function()
        M.open_workbench()
    end

    dap.listeners.after.event_process["debug_workbench"] = function(_, body)
        if body and body.systemProcessId then
            M.set_resource_pid(body.systemProcessId, body.name, { quiet = true })
        end
    end

    dap.listeners.after.event_exited["debug_workbench"] = function()
        M.refresh_resources()
    end

    dap.listeners.before.event_terminated["debug_workbench"] = function()
        M.on_session_end()
    end

    dap.listeners.before.event_exited["debug_workbench"] = function()
        M.refresh_resources()
    end
end

function M.check_adapters()
    local lines, level = adapter_health()
    notify(table.concat(lines, "\n"), level)
    return lines
end

return M
