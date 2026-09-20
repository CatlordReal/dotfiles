local M = {}
local defaults = { latte = "07:00", frappe = "16:00", macchiato = "19:00", mocha = "22:00" }
local order = { "latte", "frappe", "macchiato", "mocha" }
local state_file = vim.fn.stdpath("state") .. "/theme-rotation.json"
local state = { enabled = false, schedule = vim.deepcopy(defaults) }
local apply, timer

local function minutes(value)
    if type(value) ~= "string" then return nil end
    local h, m = value:match("^(%d%d):(%d%d)$")
    h, m = tonumber(h), tonumber(m)
    if not h or h > 23 or m > 59 then return nil end
    return h * 60 + m
end

function M.validate(schedule)
    if type(schedule) ~= "table" then return false end
    local previous = -1
    for _, flavour in ipairs(order) do
        local value = minutes(schedule[flavour])
        if not value or value <= previous then return false end
        previous = value
    end
    return true
end

do
    local ok, lines = pcall(vim.fn.readfile, state_file)
    if ok then
        local decoded, data = pcall(vim.json.decode, table.concat(lines, "\n"))
        if decoded and type(data) == "table" and M.validate(data.schedule) then
            state = { enabled = data.enabled == true, schedule = data.schedule }
        end
    end
end

local function save()
    vim.fn.mkdir(vim.fn.fnamemodify(state_file, ":h"), "p")
    vim.fn.writefile({ vim.json.encode(state) }, state_file)
end

function M.theme_at(hour, minute, schedule)
    schedule = schedule or state.schedule
    assert(M.validate(schedule), "Rotation times must be increasing HH:MM values")
    local now, flavour = hour * 60 + (minute or 0), "mocha"
    for _, candidate in ipairs(order) do
        if now >= minutes(schedule[candidate]) then flavour = candidate end
    end
    return "catppuccin-" .. flavour
end

function M.enabled() return state.enabled end

function M.current()
    local now = os.date("*t")
    return M.theme_at(now.hour, now.min)
end

function M.tick(force)
    if not state.enabled or not apply then return end
    local theme = M.current()
    if force or theme ~= vim.g.color_theme then
        apply(theme, { persist = false, rotation = true })
    end
end

function M.stop()
    if state.enabled then
        state.enabled = false
        save()
    end
end

function M.start()
    state.enabled = true
    save()
    M.tick(true)
end

function M.configure()
    local draft = vim.deepcopy(state.schedule)
    local function ask(index)
        local flavour = order[index]
        if not flavour then
            if not M.validate(draft) then
                vim.notify("Times must increase from Latte to Mocha (HH:MM)", vim.log.levels.ERROR)
                return
            end
            state.schedule = draft
            save()
            M.tick(true)
            return
        end
        vim.ui.input({ prompt = flavour .. " starts (local HH:MM): ", default = draft[flavour] }, function(value)
            if value == nil then return end
            draft[flavour] = value
            ask(index + 1)
        end)
    end
    ask(1)
end

function M.setup(callback)
    apply = callback
    if timer then timer:stop(); timer:close() end
    timer = vim.uv.new_timer()
    timer:start(30000, 30000, vim.schedule_wrap(function() M.tick() end))
    local group = vim.api.nvim_create_augroup("DotfilesThemeRotation", { clear = true })
    vim.api.nvim_create_autocmd({ "FocusGained", "VimResume" }, {
        group = group, callback = function() M.tick() end,
    })
    vim.api.nvim_create_autocmd("VimLeavePre", { group = group, callback = function()
        if timer and not timer:is_closing() then timer:stop(); timer:close() end
        timer = nil
    end })
    vim.api.nvim_create_user_command("ColorThemeRotation", function(opts)
        if opts.args == "off" then
            M.stop()
            -- Keep the currently visible theme after restarting Neovim.
            callback(vim.g.color_theme)
        elseif opts.args == "times" then M.configure()
        else M.start() end
    end, { nargs = "?", complete = function() return { "on", "off", "times" } end,
        desc = "Catppuccin rotation: on, off, or times" })
    M.tick(true)
end

return M
