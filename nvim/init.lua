-- Set leader and general options
vim.g.mapleader = " "
vim.opt.termguicolors = true
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.signcolumn = "yes"
vim.opt.scrolloff = 6
vim.opt.softtabstop = 4
-- Faster update time for diagnostics
vim.opt.updatetime = 200 -- NTS: Extra addition
vim.opt.winblend = 0
vim.opt.pumblend = 0
vim.opt.cursorlineopt = "number"
vim.o.winborder = "rounded"
vim.opt.virtualedit = ""
vim.opt.shortmess:append("I")

vim.filetype.add({
    extension = {
        axaml = "xml",
        xaml = "xml",
    },
})

local function prepend_env_path(path)
    if type(path) ~= "string" or path == "" then
        return
    end

    local expanded = vim.fn.expand(path)
    if expanded == nil or expanded == "" or vim.fn.isdirectory(expanded) ~= 1 then
        return
    end

    local current = vim.env.PATH or ""
    local sep = (vim.uv.os_uname().sysname:lower():find("windows") and ";") or ":"
    if current == expanded
        or vim.startswith(current, expanded .. sep)
        or vim.endswith(current, sep .. expanded)
        or current:find(sep .. expanded .. sep, 1, true)
    then
        return
    end

    vim.env.PATH = current == "" and expanded or (expanded .. sep .. current)
end

prepend_env_path("~/.local/bin")
prepend_env_path("~/.dotnet")
prepend_env_path("~/.dotnet/tools")

if (vim.env.DOTNET_ROOT == nil or vim.env.DOTNET_ROOT == "") and vim.fn.isdirectory(vim.fn.expand("~/.dotnet")) == 1 then
    vim.env.DOTNET_ROOT = vim.fn.expand("~/.dotnet")
end


local CATPPUCCIN_DEFAULT_THEME = "mocha"
local catppuccin_flavour_list = { "latte", "frappe", "macchiato", "mocha" }
local catppuccin_flavour_file = vim.fn.stdpath("state") .. "/catppuccin_flavour.txt"
local color_theme_file = vim.fn.stdpath("state") .. "/color_theme.txt"
local kitty_config_file = vim.fn.expand("~/.config/kitty/kitty.conf")
local kitty_current_theme_file = vim.fn.expand("~/.config/kitty/current-theme.conf")

local function normalize_catppuccin_flavour(flavour)
    if type(flavour) ~= "string" then
        return CATPPUCCIN_DEFAULT_THEME
    end
    local value = flavour:lower()
    for _, candidate in ipairs(catppuccin_flavour_list) do
        if candidate == value then
            return value
        end
    end
    return CATPPUCCIN_DEFAULT_THEME
end

local function read_catppuccin_flavour()
    local ok, lines = pcall(vim.fn.readfile, catppuccin_flavour_file)
    if not ok or type(lines) ~= "table" or #lines == 0 then
        return nil
    end
    return normalize_catppuccin_flavour(lines[1])
end

local function persist_catppuccin_flavour(flavour)
    local value = normalize_catppuccin_flavour(flavour)
    local state_dir = vim.fn.fnamemodify(catppuccin_flavour_file, ":h")
    vim.fn.mkdir(state_dir, "p")
    local ok = vim.fn.writefile({ value }, catppuccin_flavour_file)
    if ok ~= 0 then
        vim.notify("Failed to persist Catppuccin flavour", vim.log.levels.WARN)
    end
end

local color_theme_specs = {
    {
        id = "catppuccin-latte",
        label = "Catppuccin Latte",
        catppuccin = "latte",
        kitty = "Catppuccin-Latte",
    },
    {
        id = "catppuccin-frappe",
        label = "Catppuccin Frappe",
        catppuccin = "frappe",
        kitty = "Catppuccin-Frappe",
    },
    {
        id = "catppuccin-macchiato",
        label = "Catppuccin Macchiato",
        catppuccin = "macchiato",
        kitty = "Catppuccin-Macchiato",
    },
    {
        id = "catppuccin-mocha",
        label = "Catppuccin Mocha",
        catppuccin = "mocha",
        kitty = "Catppuccin-Mocha",
    },
}

local color_theme_by_id = {}
local color_theme_by_kitty_name = {}
for _, spec in ipairs(color_theme_specs) do
    color_theme_by_id[spec.id] = spec
    if type(spec.kitty) == "string" and spec.kitty ~= "" then
        color_theme_by_kitty_name[spec.kitty:lower()] = spec
    end
end

local COLOR_THEME_DEFAULT = "catppuccin-" .. CATPPUCCIN_DEFAULT_THEME

local function normalize_color_theme_id(theme_id)
    if type(theme_id) ~= "string" then
        return COLOR_THEME_DEFAULT
    end

    local value = theme_id:lower():gsub("_", "-"):gsub("%s+", "-")
    if color_theme_by_id[value] then
        return value
    end

    local kitty_match = color_theme_by_kitty_name[value]
    if kitty_match then
        return kitty_match.id
    end

    return COLOR_THEME_DEFAULT
end

local function get_color_theme_spec(theme_id)
    return color_theme_by_id[normalize_color_theme_id(theme_id)]
end

local function catppuccin_flavour_to_theme_id(flavour)
    return "catppuccin-" .. normalize_catppuccin_flavour(flavour)
end

local function persist_color_theme(theme_id)
    local spec = get_color_theme_spec(theme_id)
    if not spec then
        return
    end

    local state_dir = vim.fn.fnamemodify(color_theme_file, ":h")
    vim.fn.mkdir(state_dir, "p")
    local ok = vim.fn.writefile({ spec.id }, color_theme_file)
    if ok ~= 0 then
        vim.notify("Failed to persist colour theme", vim.log.levels.WARN)
    end

    if spec.catppuccin then
        persist_catppuccin_flavour(spec.catppuccin)
    end
end

local function read_kitty_theme_name()
    local ok, lines = pcall(vim.fn.readfile, kitty_current_theme_file)
    if not ok or type(lines) ~= "table" or #lines == 0 then
        return nil
    end

    for _, line in ipairs(lines) do
        local name = line:match("^##%s*name:%s*(.-)%s*$")
        if name and name ~= "" then
            return name
        end
    end

    return nil
end

local function read_color_theme_id()
    local ok, lines = pcall(vim.fn.readfile, color_theme_file)
    if ok and type(lines) == "table" and #lines > 0 then
        local value = normalize_color_theme_id(lines[1])
        if color_theme_by_id[value] then
            return value
        end
    end

    local legacy_flavour = read_catppuccin_flavour()
    if legacy_flavour then
        return catppuccin_flavour_to_theme_id(legacy_flavour)
    end

    local kitty_theme_name = read_kitty_theme_name()
    if type(kitty_theme_name) == "string" and kitty_theme_name ~= "" then
        local spec = color_theme_by_kitty_name[kitty_theme_name:lower()]
        if spec then
            return spec.id
        end
    end

    return nil
end

local function update_kitty_theme_comment(kitty_theme_name)
    if vim.fn.filereadable(kitty_config_file) ~= 1 then
        return false, "Kitty config file not found"
    end

    local ok, lines = pcall(vim.fn.readfile, kitty_config_file)
    if not ok or type(lines) ~= "table" then
        return false, "Failed to read kitty.conf"
    end

    local begin_idx
    local end_idx
    for i, line in ipairs(lines) do
        if line == "# BEGIN_KITTY_THEME" then
            begin_idx = i
        elseif line == "# END_KITTY_THEME" then
            end_idx = i
            break
        end
    end

    if not begin_idx or not end_idx or end_idx <= begin_idx then
        return false, "Kitty theme block not found"
    end

    local comment_line = "# " .. kitty_theme_name
    local comment_updated = false
    for i = begin_idx + 1, end_idx - 1 do
        if lines[i]:match("^#%s") then
            lines[i] = comment_line
            comment_updated = true
            break
        end
    end

    if not comment_updated then
        table.insert(lines, begin_idx + 1, comment_line)
    end

    if vim.fn.writefile(lines, kitty_config_file) ~= 0 then
        return false, "Failed to update kitty.conf"
    end

    return true
end

local function sync_kitty_theme(theme_id, opts)
    opts = opts or {}
    local spec = get_color_theme_spec(theme_id)
    if not spec or not spec.kitty then
        return true
    end

    if vim.fn.executable("kitty") ~= 1 then
        return false, "kitty is not installed"
    end

    local theme_contents = vim.fn.system({ "kitty", "+kitten", "themes", "--dump-theme", spec.kitty })
    if vim.v.shell_error ~= 0 then
        local message = vim.trim(theme_contents or "")
        if message == "" then
            message = "Failed to dump Kitty theme " .. spec.kitty
        end
        return false, message
    end

    local lines = vim.split(theme_contents, "\n", { plain = true, trimempty = false })
    if #lines > 0 and lines[#lines] == "" then
        table.remove(lines, #lines)
    end

    vim.fn.mkdir(vim.fn.fnamemodify(kitty_current_theme_file, ":h"), "p")
    if vim.fn.writefile(lines, kitty_current_theme_file) ~= 0 then
        return false, "Failed to write Kitty current theme"
    end

    local ok_comment, comment_err = update_kitty_theme_comment(spec.kitty)
    if not ok_comment then
        return false, comment_err
    end

    local can_reload_live = (vim.env.KITTY_LISTEN_ON and vim.env.KITTY_LISTEN_ON ~= "")
        or (vim.env.KITTY_WINDOW_ID and vim.env.KITTY_WINDOW_ID ~= "")
    if opts.reload ~= false and can_reload_live then
        local reload_output = vim.fn.system({ "kitty", "@", "set-colors", "--all", "--configured", kitty_current_theme_file })
        if vim.v.shell_error ~= 0 then
            local message = vim.trim(reload_output or "")
            if message == "" then
                message = "Failed to reload Kitty colours"
            end
            return false, message
        end
    end

    return true
end

local function catppuccin_reactive_load(flavour)
    local value = normalize_catppuccin_flavour(flavour)
    return {
        "catppuccin-" .. value .. "-cursor",
        "catppuccin-" .. value .. "-cursorline",
    }
end

local function clear_catppuccin_feline_cache()
    package.loaded["catppuccin.groups.integrations.feline"] = nil
    package.loaded["catppuccin.special.feline"] = nil
end

local function clear_catppuccin_reactive_presets()
    local ok_state, state = pcall(require, "reactive.state")
    if not ok_state then
        return
    end

    for preset_name, _ in pairs(state.presets or {}) do
        local is_catppuccin_cursor = preset_name:match("^catppuccin%-%a+%-cursor$")
            or preset_name:match("^catppuccin%-%a+%-cursorline$")
        if is_catppuccin_cursor then
            pcall(state.disable_preset, state, preset_name)
        end
    end
end

local function clear_feline_cache()
    for name, _ in pairs(package.loaded) do
        if name:match("^feline") then
            package.loaded[name] = nil
        end
    end
end

local function load_catppuccin_colorscheme(flavour)
    local value = normalize_catppuccin_flavour(flavour)
    vim.g.catppuccin_flavour = value
    vim.o.background = (value == "latte") and "light" or "dark"

    local target = "catppuccin-" .. value
    local ok = pcall(vim.cmd.colorscheme, target)
    if not ok then
        pcall(vim.cmd.colorscheme, "catppuccin")
        pcall(vim.cmd, "Catppuccin " .. value)
    end

    -- Ensure we end up on the exact flavour, even if another plugin changed colorscheme.
    if vim.g.colors_name ~= target then
        pcall(vim.cmd.colorscheme, target)
    end
end

local function apply_catppuccin_theme(flavour, opts)
    opts = opts or {}
    local value = normalize_catppuccin_flavour(flavour or vim.g.catppuccin_flavour or CATPPUCCIN_DEFAULT_THEME)
    local theme_id = normalize_color_theme_id(opts.theme_id or catppuccin_flavour_to_theme_id(value))
    vim.g.color_theme = theme_id
    vim.g.catppuccin_flavour = value

    local ok_theme, theme_err = pcall(function()
        vim.o.background = (value == "latte") and "light" or "dark"
        if type(_G.__setup_catppuccin_theme) == "function" then
            _G.__setup_catppuccin_theme(value)
        else
            local ok_catppuccin, catppuccin = pcall(require, "catppuccin")
            if ok_catppuccin then
                catppuccin.setup({ flavour = value, auto_integrations = true })
            end
        end

        if type(_G.__load_catppuccin_flavour) == "function" then
            _G.__load_catppuccin_flavour(value)
        else
            load_catppuccin_colorscheme(value)
        end
    end)
    if not ok_theme then
        vim.notify("Failed to apply Catppuccin theme: " .. tostring(theme_err), vim.log.levels.ERROR)
        return
    end

    clear_catppuccin_feline_cache()

    if type(_G.__setup_feline_catppuccin) == "function" then
        local ok_feline, feline_err = pcall(_G.__setup_feline_catppuccin, value)
        if not ok_feline then
            vim.notify("Feline refresh failed: " .. tostring(feline_err), vim.log.levels.WARN)
        end
    end
    if type(_G.__setup_reactive_catppuccin) == "function" then
        local ok_reactive, reactive_err = pcall(_G.__setup_reactive_catppuccin, value)
        if not ok_reactive then
            vim.notify("Reactive refresh failed: " .. tostring(reactive_err), vim.log.levels.WARN)
        end
    end

    if opts.persist ~= false then
        persist_color_theme(theme_id)
    end

    if opts.sync_kitty ~= false then
        local ok_kitty, kitty_err = sync_kitty_theme(theme_id, {
            reload = opts.reload_kitty ~= false,
        })
        if not ok_kitty then
            vim.notify("Kitty theme sync failed: " .. tostring(kitty_err), vim.log.levels.WARN)
        end
    end

    vim.cmd("redrawstatus")
    vim.cmd("redraw!")
end

local function choose_catppuccin_flavour()
    local themes = color_theme_specs
    local current = normalize_color_theme_id(vim.g.color_theme or catppuccin_flavour_to_theme_id(vim.g.catppuccin_flavour))
    local lines = {
        "Colour Theme",
        "j/k move, <CR> choose, 1-" .. tostring(#themes) .. " quick select, q close",
        "",
    }

    for i, theme in ipairs(themes) do
        local marker = theme.id == current and "*" or " "
        table.insert(lines, string.format("%s %d. %s", marker, i, theme.label))
    end

    local width = 0
    for _, line in ipairs(lines) do
        width = math.max(width, vim.fn.strdisplaywidth(line))
    end
    width = math.max(width + 4, 44)
    local height = #lines

    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].modifiable = true
    vim.bo[buf].filetype = "color-theme-picker"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false

    local row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1)
    local col = math.max(0, math.floor((vim.o.columns - width) / 2))
    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        style = "minimal",
        border = "rounded",
        width = width,
        height = height,
        row = row,
        col = col,
    })

    vim.wo[win].cursorline = true
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "no"

    local first_choice_row = 4
    local last_choice_row = first_choice_row + #themes - 1
    local start_row = first_choice_row
    for i, theme in ipairs(themes) do
        if theme.id == current then
            start_row = first_choice_row + i - 1
            break
        end
    end
    vim.api.nvim_win_set_cursor(win, { start_row, 0 })

    local function close_picker()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end

    local function select_index(index)
        local theme = themes[index]
        if not theme then
            return
        end
        close_picker()
        apply_catppuccin_theme(theme.catppuccin, { theme_id = theme.id })
    end

    local function select_current_row()
        if not vim.api.nvim_win_is_valid(win) then
            return
        end
        local cursor_row = vim.api.nvim_win_get_cursor(win)[1]
        local index = cursor_row - first_choice_row + 1
        select_index(index)
    end

    local function move_cursor(delta)
        if not vim.api.nvim_win_is_valid(win) then
            return
        end
        local cursor_row = vim.api.nvim_win_get_cursor(win)[1]
        local new_row = math.min(last_choice_row, math.max(first_choice_row, cursor_row + delta))
        vim.api.nvim_win_set_cursor(win, { new_row, 0 })
    end

    local keyopts = { buffer = buf, nowait = true, silent = true }
    vim.keymap.set("n", "q", close_picker, keyopts)
    vim.keymap.set("n", "<Esc>", close_picker, keyopts)
    vim.keymap.set("n", "<CR>", select_current_row, keyopts)
    vim.keymap.set("n", "j", function() move_cursor(1) end, keyopts)
    vim.keymap.set("n", "k", function() move_cursor(-1) end, keyopts)
    vim.keymap.set("n", "<Down>", function() move_cursor(1) end, keyopts)
    vim.keymap.set("n", "<Up>", function() move_cursor(-1) end, keyopts)

    for i = 1, #themes do
        vim.keymap.set("n", tostring(i), function() select_index(i) end, keyopts)
    end
end

vim.g.color_theme = normalize_color_theme_id(read_color_theme_id() or COLOR_THEME_DEFAULT)
vim.g.catppuccin_flavour = normalize_catppuccin_flavour(
    (get_color_theme_spec(vim.g.color_theme) or {}).catppuccin or CATPPUCCIN_DEFAULT_THEME
)

vim.api.nvim_create_user_command("CatppuccinFlavour", choose_catppuccin_flavour, {
    desc = "Pick colour theme",
})
vim.api.nvim_create_user_command("ColorTheme", choose_catppuccin_flavour, {
    desc = "Pick colour theme",
})
vim.api.nvim_create_user_command("KittyThemeSync", function()
    local ok, err = sync_kitty_theme(vim.g.color_theme or catppuccin_flavour_to_theme_id(vim.g.catppuccin_flavour))
    if not ok then
        vim.notify("Kitty theme sync failed: " .. tostring(err), vim.log.levels.WARN)
        return
    end
    vim.notify("Kitty theme synced", vim.log.levels.INFO)
end, {
    desc = "Sync Kitty with the current colour theme",
})


vim.diagnostic.config({
    virtual_text = {
        severity = { min = vim.diagnostic.severity.ERROR },
    },
    underline = {
        severity = { min = vim.diagnostic.severity.WARN },
    },
    signs = {
        severity = { min = vim.diagnostic.severity.WARN },
    },
})
vim.api.nvim_create_user_command("CatppuccinMocha", function()
    apply_catppuccin_theme(CATPPUCCIN_DEFAULT_THEME)
end, {
    desc = "Reapply Catppuccin Mocha",
})

-- lazy.nvim bootstrap
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    -- TODO: Put all mini things in one mini.nvim block

    -- mini.jump2d (jumping further than s binding can)
    {
        "echasnovski/mini.jump2d",
        version = "*",
        config = function()
            local jump2d = require("mini.jump2d")
            jump2d.setup({
                -- This binds it to your Enter key in Normal mode
                mappings = {
                    start_jumping = "<CR>",
                },
                view = {
                    -- Fades out the rest of the code so the labels pop
                    dim = true,
                    -- Use the 'n' style labels (letters) for the fastest jumping
                    n_steps_ahead = 2,
                },
                -- This makes it jump to the START of words (perfect for code)
                allowed_lines = { blank = false },
                hooks = {
                    after_jump = function()
                        -- Optional: Pulse the cursor after jumping so you don't lose it
                        vim.cmd("normal! zvzz")
                    end,
                },
            })
        end,
    },

    -- mini.animate (cursor animations)
    {
        "echasnovski/mini.animate",
        version = "*",
        config = function()
            local animate = require("mini.animate")

            animate.setup({
                -- scroll = {
                --   enable = true,
                --   timing = animate.gen_timing.linear({ duration = 150, unit = "total" }),
                --   subscroll = animate.gen_subscroll.equal({
                --       predicate = function(total_scroll)
                --           return total_scroll <= 20
                --       end,
                --   }),
              -- },
                cursor = {
                    enable = true,
                    timing = animate.gen_timing.linear({ duration = 75, unit = "total" }),
                    path = animate.gen_path.line({
                        predicate = function(destination)
                            return math.abs(destination[1]) <= 25 and math.abs(destination[2]) <= 80
                        end,
                    }),
                },
                resize = { enable = false },
                open = { enable = false },
                close = { enable = false },
            })
        end,
    },
    -- surround-ui (ui for surround)
    {
        "roobert/surround-ui.nvim",
        dependencies = {
            "kylechui/nvim-surround",
            "folke/which-key.nvim",
        },
        config = function()
            require("surround-ui").setup({
                root_key = "S"
            })
        end,
    },
    -- dropbar
    {
        'Bekaboo/dropbar.nvim',
        -- optional, but required for fuzzy finder support
        dependencies = {
            'nvim-telescope/telescope-fzf-native.nvim',
            build = 'make'
        },
        config = function()
            local dropbar_api = require('dropbar.api')
            vim.keymap.set('n', '<Leader>;', dropbar_api.pick, { desc = 'Pick symbols in winbar' })
            vim.keymap.set('n', '[;', dropbar_api.goto_context_start, { desc = 'Go to start of current context' })
            vim.keymap.set('n', '];', dropbar_api.select_next_context, { desc = 'Select next context' })
        end
    },
    -- mini files
    {
        "echasnovski/mini.files",
        dependencies = { "nvim-mini/mini.icons" },
        config = function()
            require("mini.files").setup({
                windows = {
                    width = 40,
                    preview = true,
                    width_preview = 80,
                },
                content = {},
                mappings = {
                    close = "<Esc>",
                    go_in = "<CR>",
                    go_out = "<BS>",
                    show_help = "g?",
                },
            })

            vim.api.nvim_create_autocmd("FileType", {
                pattern = { "minifiles", "oil" },
                callback = function(args)
                    vim.b[args.buf].minianimate_disable = true
                end,
            })
        end,
    },
    -- Snacks
    {
        "folke/snacks.nvim",
        priority = 1000,
        lazy = false,
        ---@type snacks.Config
        opts = {
            bigfile = { enabled = true },
            dashboard = {
                enabled = true,
                sections = {
                    { section = "header" },
                    {
                        pane = 2,
                        section = "terminal",
                        enabled = function()
                            return vim.fn.executable("colorscript") == 1
                        end,
                        cmd = "colorscript -e square",
                        height = 5,
                        padding = 1,
                    },
                    { section = "keys", gap = 1, padding = 1 },
                    { pane = 2, icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 1 },
                    { pane = 2, icon = " ", title = "Projects", section = "projects", indent = 2, padding = 1 },
                    {
                        pane = 2,
                        icon = " ",
                        title = "Git Status",
                        section = "terminal",
                        enabled = function()
                            return Snacks.git.get_root() ~= nil
                        end,
                        cmd = "git status --short --branch --renames",
                        height = 5,
                        padding = 1,
                        ttl = 5 * 60,
                        indent = 3,
                    },
                    { section = "startup" },
                },
            },
            explorer = { enabled = false },
            indent = { enabled = true },
            input = { enabled = true },
            notifier = {
                enabled = true,
                timeout = 3000,
            },
            picker = {
                enabled = true,
                sources = {
                    projects = {
                        dev = { "~/dev/projects" },
                    },
                },
            },
            quickfile = { enabled = true },
            scope = { enabled = true },
            scroll = { enabled = false },
            statuscolumn = { enabled = true },
            words = { enabled = true },
            styles = {
                notification = {
                    -- wo = { wrap = true } -- Wrap notifications
                }
            }
        },
        keys = {
            -- Snacks Jumps
            { "<leader>j",       group = "Jump" },
            { "<leader>js",      function() Snacks.scope.jump(1) end,                                    desc = "Next Scope" },
            { "<leader>jS",      function() Snacks.scope.jump(-1) end,                                   desc = "Prev Scope" },
            -- Top Pickers & Explorer
            { "<leader><space>", function() Snacks.picker.smart() end,                                   desc = "Smart Find Files" },
            { "<leader>,",       function() Snacks.picker.buffers() end,                                 desc = "Buffers" },
            { "<leader>/",       function() Snacks.picker.grep() end,                                    desc = "Grep" },
            { "<leader>:",       function() Snacks.picker.command_history() end,                         desc = "Command History" },
            -- { "<leader>nn",       function() Snacks.picker.notifications() end,                           desc = "Notification History" },
            { "<leader>e",       function() Snacks.explorer() end,                                       desc = "File Explorer" },
            -- find
            { "<leader>fb",      function() Snacks.picker.buffers() end,                                 desc = "Buffers" },
            { "<leader>fc",      function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end, desc = "Find Config File" },
            { "<leader>ff",      function() Snacks.picker.files() end,                                   desc = "Find Files" },
            { "<leader>fg",      function() Snacks.picker.git_files() end,                               desc = "Find Git Files" },
            { "<leader>fp",      function() Snacks.picker.projects() end,                                desc = "Projects" },
            { "<leader>fr",      function() Snacks.picker.recent() end,                                  desc = "Recent" },
            -- git
            { "<leader>gb",      function() Snacks.picker.git_branches() end,                            desc = "Git Branches" },
            { "<leader>gl",      function() Snacks.picker.git_log() end,                                 desc = "Git Log" },
            { "<leader>gL",      function() Snacks.picker.git_log_line() end,                            desc = "Git Log Line" },
            { "<leader>gs",      function() Snacks.picker.git_status() end,                              desc = "Git Status" },
            { "<leader>gS",      function() Snacks.picker.git_stash() end,                               desc = "Git Stash" },
            { "<leader>gd",      function() Snacks.picker.git_diff() end,                                desc = "Git Diff (Hunks)" },
            { "<leader>gf",      function() Snacks.picker.git_log_file() end,                            desc = "Git Log File" },
            -- gh
            { "<leader>gi",      function() Snacks.picker.gh_issue() end,                                desc = "GitHub Issues (open)" },
            { "<leader>gI",      function() Snacks.picker.gh_issue({ state = "all" }) end,               desc = "GitHub Issues (all)" },
            { "<leader>gp",      function() Snacks.picker.gh_pr() end,                                   desc = "GitHub Pull Requests (open)" },
            { "<leader>gP",      function() Snacks.picker.gh_pr({ state = "all" }) end,                  desc = "GitHub Pull Requests (all)" },
            -- Grep
            { "<leader>sb",      function() Snacks.picker.lines() end,                                   desc = "Buffer Lines" },
            { "<leader>sB",      function() Snacks.picker.grep_buffers() end,                            desc = "Grep Open Buffers" },
            { "<leader>sg",      function() Snacks.picker.grep() end,                                    desc = "Grep" },
            { "<leader>sw",      function() Snacks.picker.grep_word() end,                               desc = "Visual selection or word",   mode = { "n", "x" } },
            -- search
            { '<leader>s"',      function() Snacks.picker.registers() end,                               desc = "Registers" },
            { '<leader>s/',      function() Snacks.picker.search_history() end,                          desc = "Search History" },
            { "<leader>sa",      function() Snacks.picker.autocmds() end,                                desc = "Autocmds" },
            { "<leader>sb",      function() Snacks.picker.lines() end,                                   desc = "Buffer Lines" },
            { "<leader>sc",      function() Snacks.picker.command_history() end,                         desc = "Command History" },
            { "<leader>sC",      function() Snacks.picker.commands() end,                                desc = "Commands" },
            { "<leader>sd",      open_buffer_diagnostics_qf,                                             desc = "Diagnostics List" },
            { "<leader>sD",      function() Snacks.picker.diagnostics_buffer() end,                      desc = "Buffer Diagnostics" },
            { "<leader>sh",      function() Snacks.picker.help() end,                                    desc = "Help Pages" },
            { "<leader>sH",      function() Snacks.picker.highlights() end,                              desc = "Highlights" },
            { "<leader>si",      function() Snacks.picker.icons() end,                                   desc = "Icons" },
            { "<leader>sj",      function() Snacks.picker.jumps() end,                                   desc = "Jumps" },
            { "<leader>sk",      function() Snacks.picker.keymaps() end,                                 desc = "Keymaps" },
            { "<leader>sl",      function() Snacks.picker.loclist() end,                                 desc = "Location List" },
            { "<leader>sm",      function() Snacks.picker.marks() end,                                   desc = "Marks" },
            { "<leader>sM",      function() Snacks.picker.man() end,                                     desc = "Man Pages" },
            { "<leader>sp",      function() Snacks.picker.lazy() end,                                    desc = "Search for Plugin Spec" },
            { "<leader>sq",      function() Snacks.picker.qflist() end,                                  desc = "Quickfix List" },
            { "<leader>sR",      function() Snacks.picker.resume() end,                                  desc = "Resume" },
            { "<leader>su",      function() Snacks.picker.undo() end,                                    desc = "Undo History" },
            { "<leader>uC",      function() Snacks.picker.colorschemes() end,                            desc = "Colorschemes" },
            { "<leader>cc",      choose_catppuccin_flavour,                                              desc = "Choose Colour Theme" },
            -- LSP
            { "gd",              function() Snacks.picker.lsp_definitions() end,                         desc = "Goto Definition" },
            { "gD",              function() Snacks.picker.lsp_declarations() end,                        desc = "Goto Declaration" },
            { "gr",              function() Snacks.picker.lsp_references() end,                          nowait = true,                       desc = "References" },
            { "gI",              function() Snacks.picker.lsp_implementations() end,                     desc = "Goto Implementation" },
            { "gy",              function() Snacks.picker.lsp_type_definitions() end,                    desc = "Goto T[y]pe Definition" },
            { "gai",             function() Snacks.picker.lsp_incoming_calls() end,                      desc = "C[a]lls Incoming" },
            { "gao",             function() Snacks.picker.lsp_outgoing_calls() end,                      desc = "C[a]lls Outgoing" },
            { "<leader>ss",      function() Snacks.picker.lsp_symbols() end,                             desc = "LSP Symbols" },
            { "<leader>sS",      function() Snacks.picker.lsp_workspace_symbols() end,                   desc = "LSP Workspace Symbols" },
            -- Other
            { "<leader>z",       function() Snacks.zen() end,                                            desc = "Toggle Zen Mode" },
            { "<leader>Z",       function() Snacks.zen.zoom() end,                                       desc = "Toggle Zoom" },
            { "<leader>.",       function() Snacks.scratch() end,                                        desc = "Toggle Scratch Buffer" },
            { "<leader>S",       function() Snacks.scratch.select() end,                                 desc = "Select Scratch Buffer" },
            { "<leader>nn",      function() Snacks.notifier.show_history() end,                          desc = "Notification History" },
            { "<leader>bd",      function() Snacks.bufdelete() end,                                      desc = "Delete Buffer" },
            { "<leader>cR",      function() Snacks.rename.rename_file() end,                             desc = "Rename File" },
            { "<leader>gB",      function() Snacks.gitbrowse() end,                                      desc = "Git Browse",                 mode = { "n", "v" } },
            { "<leader>gg",      function() Snacks.lazygit() end,                                        desc = "Lazygit" },
            { "<leader>un",      function() Snacks.notifier.hide() end,                                  desc = "Dismiss All Notifications" },
            { "<c-/>",           function() Snacks.terminal() end,                                       desc = "Toggle Terminal" },
            { "<c-_>",           function() Snacks.terminal() end,                                       desc = "which_key_ignore" },
            { "]]",              function() Snacks.words.jump(vim.v.count1) end,                         desc = "Next Reference",             mode = { "n", "t" } },
            { "[[",              function() Snacks.words.jump(-vim.v.count1) end,                        desc = "Prev Reference",             mode = { "n", "t" } },
            {
                "<leader>N",
                desc = "Neovim News",
                function()
                    Snacks.win({
                        file = vim.api.nvim_get_runtime_file("doc/news.txt", false)[1],
                        width = 0.6,
                        height = 0.6,
                        wo = {
                            spell = false,
                            wrap = false,
                            signcolumn = "yes",
                            statuscolumn = " ",
                            conceallevel = 3,
                        },
                    })
                end,
            }
        },
        init = function()
            vim.api.nvim_create_autocmd("User", {
                pattern = "VeryLazy",
                callback = function()
                    -- Setup some globals for debugging (lazy-loaded)
                    _G.dd = function(...)
                        Snacks.debug.inspect(...)
                    end
                    _G.bt = function()
                        Snacks.debug.backtrace()
                    end

                    -- Override print to use snacks for `:=` command
                    if vim.fn.has("nvim-0.11") == 1 then
                        vim._print = function(_, ...)
                            dd(...)
                        end
                    else
                        vim.print = _G.dd
                    end

                    -- Create some toggle mappings
                    Snacks.toggle.option("spell", { name = "Spelling" }):map("<leader>us")
                    Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
                    Snacks.toggle.option("relativenumber", { name = "Relative Number" }):map("<leader>uL")
                    Snacks.toggle.diagnostics():map("<leader>ud")
                    Snacks.toggle.line_number():map("<leader>ul")
                    Snacks.toggle.option("conceallevel",
                        { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2 }):map("<leader>uc")
                    Snacks.toggle.treesitter():map("<leader>uT")
                    Snacks.toggle.option("background", { off = "light", on = "dark", name = "Dark Background" }):map(
                        "<leader>ub")
                    Snacks.toggle.inlay_hints():map("<leader>uh")
                    Snacks.toggle.indent():map("<leader>ug")
                    Snacks.toggle.dim():map("<leader>uD")
                end,
            })
        end,
    },
    -- DOTNET running
    {
        "GustavEikaas/easy-dotnet.nvim",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "mfussenegger/nvim-dap",
        },
        config = function()
            local cached_easy_dotnet_version = nil

            local function get_easy_dotnet_cli_version()
                if cached_easy_dotnet_version then
                    return cached_easy_dotnet_version
                end

                local version = vim.trim(vim.fn.system({ "dotnet", "easydotnet", "-v" }))
                if vim.v.shell_error == 0 and version ~= "" then
                    cached_easy_dotnet_version = version
                    return version
                end

                cached_easy_dotnet_version = "2.0.0"
                return cached_easy_dotnet_version
            end

            local rpc_client = require("easy-dotnet.rpc.dotnet-client")
            local current_solution = require("easy-dotnet.current_solution")

            rpc_client._initialize = function(self, cb, opts)
                opts = opts or {}
                coroutine.wrap(function()
                    local easy_opts = require("easy-dotnet.options").options
                    local use_visual_studio = easy_opts.server.use_visual_studio == true
                    local debugger_path = easy_opts.debugger.bin_path
                    local apply_value_converters = easy_opts.debugger.apply_value_converters
                    local debugger_options = {
                        applyValueConverters = apply_value_converters,
                        binaryPath = debugger_path,
                    }

                    current_solution.get_or_pick_solution(function(sln_file)
                        rpc_client.create_rpc_call({
                            client = self._client,
                            job = {
                                name = "Initializing...",
                                on_success_text = "Client initialized",
                                on_error_text = "Failed to initialize server",
                            },
                            cb = cb,
                            on_crash = opts.on_crash,
                            method = "initialize",
                            params = {
                                request = {
                                    clientInfo = {
                                        name = "EasyDotnet",
                                        version = get_easy_dotnet_cli_version(),
                                    },
                                    projectInfo = {
                                        rootDir = vim.fs.normalize(vim.fn.getcwd()),
                                        solutionFile = sln_file,
                                    },
                                    options = {
                                        useVisualStudio = use_visual_studio,
                                        debuggerOptions = debugger_options,
                                    },
                                },
                            },
                        })()
                    end)
                end)()
            end

            require("easy-dotnet").setup()
        end,
    },
    -- File explorer

    -- {
    --     "nvim-tree/nvim-tree.lua",
    --     dependencies = { "nvim-tree/nvim-web-devicons" },
    --     config = function()
    --         require("nvim-tree").setup({
    --             -- Use on_attach to customise key mappings when the tree is focused
    --             on_attach = function(bufnr)
    --                 local api = require("nvim-tree.api")
    --                 local function opts(desc)
    --                     return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
    --                 end
    --                 -- load default mappings then add our own
    --                 api.config.mappings.default_on_attach(bufnr)
    --                 -- Open the selected file in a new tab without leaving the tree when pressing 't'
    --                 vim.keymap.set("n", "t", function()
    --                     local node = api.tree.get_node_under_cursor()
    --                     if not node or node.type ~= "file" then
    --                         return
    --                     end
    --                     -- add to buffer list
    --                     vim.cmd("badd " .. vim.fn.fnameescape(node.absolute_path))
    --                     -- close the tree window if desired
    --                     api.tree.close()
    --                 end, opts("Open in buffer, close tree"))
    --             end,
    --             view = {
    --                 width = 32,
    --                 side = "left",
    --                 signcolumn = "yes",
    --             },

    --             renderer = {
    --                 root_folder_label = false,
    --                 highlight_git = true,
    --                 highlight_opened_files = "name",
    --                 indent_markers = {
    --                     enable = true,
    --                     icons = {
    --                         corner = "└ ",
    --                         edge = "│ ",
    --                         item = "│ ",
    --                         none = "  ",
    --                     },
    --                 },
    --                 icons = {
    --                     git_placement = "before",
    --                     diagnostics_placement = "after",
    --                     padding = " ",
    --                     symlink_arrow = " ➛ ",
    --                     show = {
    --                         file = true,
    --                         folder = true,
    --                         folder_arrow = false,
    --                         git = true,
    --                         diagnostics = true,
    --                     },
    --                     glyphs = {
    --                         default = "",
    --                         symlink = "",
    --                         bookmark = "",
    --                         folder = {
    --                             arrow_closed = "",
    --                             arrow_open = "",
    --                             default = "",
    --                             open = "",
    --                             empty = "",
    --                             empty_open = "",
    --                             symlink = "",
    --                             symlink_open = "",
    --                         },
    --                         git = {
    --                             unstaged = "✗",
    --                             staged = "✓",
    --                             unmerged = "",
    --                             renamed = "➜",
    --                             untracked = "★",
    --                             deleted = "",
    --                             ignored = "◌",
    --                         },
    --                     },
    --                 },
    --             },
    --         })
    --         -- Leader key mapping for toggling the tree
    --         vim.keymap.set("n", "<leader>nt", "<cmd>NvimTreeToggle<CR>", { silent = true, desc = "Toggle Nvim Tree" })
    --     end,
    -- },
    {
        "folke/flash.nvim",
        event = "VeryLazy",
        opts = {
            modes = {
                char = {
                    enabled = false,
                },
            },
        },
    },
    {
        "rasulomaroff/reactive.nvim",
        event = { "BufEnter", "WinEnter" },
        config = function()
            _G.__setup_reactive_catppuccin = function(flavour)
                local value = normalize_catppuccin_flavour(flavour or vim.g.catppuccin_flavour)
                local ok, reactive = pcall(require, "reactive")
                if not ok then
                    return
                end
                local presets = catppuccin_reactive_load(value)
                clear_catppuccin_reactive_presets()
                reactive.setup({
                    load = presets,
                })
                local ok_state, state = pcall(require, "reactive.state")
                if ok_state then
                    for _, preset_name in ipairs(presets) do
                        if state.presets[preset_name] and state.disabled_presets[preset_name] then
                            pcall(state.enable_preset, state, preset_name)
                        end
                    end
                end
            end
            _G.__setup_reactive_catppuccin(vim.g.catppuccin_flavour)
        end,
    },
    {
        "famiu/feline.nvim",
        dependencies = { "catppuccin/nvim", "nvim-tree/nvim-web-devicons" },
        config = function()
            _G.__setup_feline_catppuccin = function(flavour)
                local value = normalize_catppuccin_flavour(flavour or vim.g.catppuccin_flavour)
                vim.g.catppuccin_flavour = value
                clear_catppuccin_feline_cache()
                clear_feline_cache()

                local feline = require("feline")
                pcall(feline.reset_highlights)

                -- Prefer the newer official Catppuccin integration path; fallback for older releases.
                local ok_groups, feline_groups = pcall(require, "catppuccin.groups.integrations.feline")
                if ok_groups and type(feline_groups.get) == "function" then
                    feline.setup({
                        components = feline_groups.get(),
                    })
                    pcall(feline.reset_highlights)
                    vim.cmd("redrawstatus")
                    return
                end

                local ok_special, feline_special = pcall(require, "catppuccin.special.feline")
                if ok_special and type(feline_special.get_statusline) == "function" then
                    local C = require("catppuccin.palettes").get_palette(value)
                    if type(feline_special.setup) == "function" then
                        feline_special.setup({
                            assets = {
                                lsp = {
                                    error = "",
                                    warning = "",
                                    info = "",
                                    hint = "󰌵",
                                },
                            },
                            sett = {
                                text = (value == "latte") and C.base or C.mantle,
                                bkg = C.crust,
                                diffs = C.mauve,
                                extras = C.overlay1,
                                curr_file = C.maroon,
                                curr_dir = C.flamingo,
                            },
                        })
                    end
                    local statusline_components = feline_special.get_statusline()
                    if statusline_components
                        and statusline_components.active
                        and statusline_components.active[2]
                    then
                        local diagnostics_section = statusline_components.active[2]
                        -- Keep statusline diagnostics aligned with visible diagnostics (WARN+).
                        if diagnostics_section[4] then
                            diagnostics_section[4].enabled = function() return false end
                        end
                        if diagnostics_section[5] then
                            diagnostics_section[5].enabled = function() return false end
                        end
                    end
                    feline.setup({
                        components = statusline_components,
                    })
                    pcall(feline.reset_highlights)
                    vim.cmd("redrawstatus")
                end
            end
            _G.__setup_feline_catppuccin(vim.g.catppuccin_flavour)
        end,
    },
    {
        "catppuccin/nvim",
        name = "catppuccin",
        lazy = false,
        priority = 1000,
        config = function(
        )
            _G.__setup_catppuccin_theme = function(flavour)
                local value = normalize_catppuccin_flavour(flavour or vim.g.catppuccin_flavour)
                require("catppuccin").setup({
                    flavour = value,
                    auto_integrations = true,
                })
            end
            _G.__load_catppuccin_flavour = function(flavour)
                local value = normalize_catppuccin_flavour(flavour or vim.g.catppuccin_flavour)
                load_catppuccin_colorscheme(value)
            end
            _G.__setup_catppuccin_theme(vim.g.catppuccin_flavour)
            _G.__load_catppuccin_flavour(vim.g.catppuccin_flavour)
            if type(_G.__setup_feline_catppuccin) == "function" then
                _G.__setup_feline_catppuccin(vim.g.catppuccin_flavour)
            end
        end,
    },
    {
        "echasnovski/mini.ai",
        event = "VeryLazy",
        opts = {},
    },
    {
        "nvimdev/lspsaga.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            require("lspsaga").setup({
                ui = {
                    border = "rounded",
                    title = true,
                },
                hover = {
                    max_width = 0.6,
                    max_height = 0.5,
                },
                code_action = {
                    show_server_name = true,
                },
                lightbulb = {
                    enable = false,
                },
            })
        end,
    },
    { "tpope/vim-repeat" },
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        opts = {
            ensure_installed = {
                "lua",
                "c",
                "cpp",
                "c_sharp",
                "swift",
                "objc",
                "json",
                "xml",
                "markdown",
                "bash",
                "python",
                "html",
                "javascript",
                "typescript",
                "css",
            },
            highlight = { enable = true },
        },
        config = function(_, o)
            require("nvim-treesitter.configs").setup(o)
        end,
    },
    { "nvim-treesitter/nvim-treesitter-context", config = function() require("treesitter-context").setup({}) end },
    { "windwp/nvim-ts-autotag",                  config = function() require("nvim-ts-autotag").setup() end },
    {
        "akinsho/bufferline.nvim",
        version = "*",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            require("bufferline").setup({
                options = {
                    mode = "buffers",
                    style_preset = require("bufferline").style_preset.default,
                    separator_style = "slant",
                    indicator = {
                        icon = "▎",
                        style = "underline",
                    },
                    hover = {
                        enabled = true,
                        delay = 200,
                        reveal = { "close" },
                    },
                    offsets = {
                        {
                            filetype = "neo-tree",
                            text = "File Explorer",
                            text_align = "left",
                            separator = true,
                        },
                    },
                    diagnostics = "nvim_lsp",
                    diagnostics_indicator = function(count, level)
                        local icon = level:match("error") and " " or " "
                        return " " .. icon .. count
                    end,
                    -- Picking and Pinning support
                    show_buffer_icons = true,
                    show_buffer_close_icons = true,
                    show_close_icon = false,
                    persist_buffer_sort = true,
                    enforce_regular_tabs = false,
                    always_show_bufferline = true,
                },
            })
        end,
    },
    {
        "nvim-telescope/telescope.nvim",
        branch = "0.1.x",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-telescope/telescope-ui-select.nvim",
            { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
        },
        config = function()
            local t = require("telescope")
            local actions = require("telescope.actions")
            local action_state = require("telescope.actions.state")
            local open_in_tab = function(prompt_bufnr)
                local entry = action_state.get_selected_entry()
                if not entry then
                    actions.close(prompt_bufnr)
                    vim.notify("No selected entry", vim.log.levels.WARN)
                    return
                end
                actions.close(prompt_bufnr)
                local path = entry.path or entry.filename or (type(entry.value) == "string" and entry.value)
                if path then
                    vim.cmd("tabnew " .. vim.fn.fnameescape(path))
                else
                    vim.notify("No file path for this entry", vim.log.levels.WARN)
                end
            end
            t.setup({
                defaults = {
                    sorting_strategy = "ascending",
                    layout_config = { prompt_position = "top" },
                    mappings = {
                        i = {
                            ["<CR>"] = open_in_tab, -- Enter in insert mode
                        },
                        n = {
                            ["<CR>"] = open_in_tab, -- Enter in normal mode
                        },
                    },
                },
                extensions = {
                    ["ui-select"] = {},
                    fzf = { fuzzy = true, case_mode = "smart_case" },
                },
            })
            t.load_extension("ui-select")
            pcall(t.load_extension, "fzf")
        end,
    },
    {
        "folke/todo-comments.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        config = function()
            require("todo-comments").setup({
                keywords = {
                    TODO = { icon = "" },
                    FIX = { icon = "" },
                    NOTE = { icon = "" },
                    NTS = { icon = "", color = "hint", alt = { "NOTICE", "NTS" } },
                },
            })
        end,
    },
    { "nvim-mini/mini.icons",    config = function() require("mini.icons").setup() end },
    {
        "stevearc/conform.nvim",
        opts = {
            formatters_by_ft = {
                lua = { "stylua" },
                python = { "ruff_format" },
                javascript = { "prettier" },
                typescript = { "prettier" },
                html = { "prettier" },
                css = { "prettier" },
                json = { "prettier" },
                markdown = { "prettier" },
            },
            format_on_save = false,
            default_format_opts = {
                lsp_format = "fallback",
            },
        },
    },
    {
        "MagicDuck/grug-far.nvim",
        config = function()
            require("grug-far").setup({})
        end,
    },
    {
        "stevearc/oil.nvim",
        opts = {
            default_file_explorer = true,
            view_options = { show_hidden = true },
        },
    },
    {
        "seblyng/roslyn.nvim",
        ft = "cs",
        opts = {},
    },
    { "lewis6991/gitsigns.nvim", config = function() require("gitsigns").setup() end },
    { "numToStr/Comment.nvim",   config = function() require("Comment").setup() end },
    { "windwp/nvim-autopairs",   config = function() require("nvim-autopairs").setup() end },
    {
        "kylechui/nvim-surround",
        version = "*",
        config = function()
            require("nvim-surround").setup()
        end,
    },
    {
        "folke/which-key.nvim",
        config = function()
            require("which-key").setup({
                preset = "helix",
                win = {
                    border = "rounded",
                    padding = { 1, 2 },
                    title = true,
                    title_pos = "center",
                    row = math.huge,
                    col = math.huge,
                    wo = { winblend = 0 },
                },
                layout = {
                    width = { min = 20, max = 100 },
                    spacing = 3,
                    align = "left",
                },
                icons = {
                    breadcrumb = "»",
                    separator = "➜",
                    group = "+",
                    mappings = true,
                    rules = {
                        { pattern = "xcode", icon = " ", color = "blue" },
                        { pattern = "harpoon", icon = "󱡀 ", color = "cyan" },
                        { pattern = "database", icon = "󰆼 ", color = "blue" },
                        { pattern = "markdown", icon = " ", color = "blue" },
                        { pattern = "persistence", icon = " ", color = "azure" },
                        { pattern = "rename", icon = "󰑕 ", color = "orange" },
                        { pattern = "reference", icon = "󰈇 ", color = "blue" },
                        { pattern = "definition", icon = "󰊕 ", color = "blue" },
                        { pattern = "implementation", icon = "󰡱 ", color = "blue" },
                        { pattern = "diagnostic", icon = "󱖫 ", color = "yellow" },
                        { pattern = "quick fix", icon = " ", color = "orange" },
                        { pattern = "toggle", icon = " ", color = "yellow" },
                        { pattern = "open", icon = " ", color = "cyan" },
                        { pattern = "close", icon = " ", color = "red" },
                        { pattern = "next", icon = " ", color = "green" },
                        { pattern = "prev", icon = " ", color = "green" },
                        { pattern = "build", icon = "󰙨 ", color = "green" },
                        { pattern = "run", icon = "󰑮 ", color = "green" },
                        { pattern = "test", icon = " ", color = "green" },
                        { pattern = "fold", icon = "󰘖 ", color = "yellow" },
                        { pattern = "query", icon = "󰆼 ", color = "blue" },
                        { pattern = "terminal", icon = " ", color = "red" },
                        { pattern = "notification", icon = "󰵅 ", color = "blue" },
                        { pattern = "jump", icon = "󰆿 ", color = "green" },
                    },
                },
            })
        end,
    },
    {
        "folke/trouble.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            require("trouble").setup()
        end,
    },
    { "aznhe21/actions-preview.nvim" },
    {
        "williamboman/mason.nvim",
        config = function()
            require("mason").setup({
                registries = {
                    "github:mason-org/mason-registry",
                    "github:Crashdummyy/mason-registry",
                },
            })
        end,
    },
    {
        "williamboman/mason-lspconfig.nvim",
        dependencies = { "neovim/nvim-lspconfig" },
        config = function()
            require("mason-lspconfig").setup({
                ensure_installed = { "lua_ls", "clangd", "pyright", "html", "lemminx" },
            })
        end,
    },
    {
        "hrsh7th/nvim-cmp",
        dependencies = {
            "hrsh7th/cmp-nvim-lsp",
            "hrsh7th/cmp-buffer",
            "hrsh7th/cmp-path",
            "hrsh7th/cmp-cmdline",
            "L3MON4D3/LuaSnip",
            "saadparwaiz1/cmp_luasnip",
            "rafamadriz/friendly-snippets",
        },
        config = function()
            local cmp = require("cmp")
            local cmp_types = require("cmp.types")
            require("luasnip.loaders.from_vscode").lazy_load()
            local cmp_window_hl = "Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:PmenuSel,Search:None"
            cmp.setup({
                window = {
                    completion = cmp.config.window.bordered({
                        border = "rounded",
                        winhighlight = cmp_window_hl,
                    }),
                    documentation = cmp.config.window.bordered({
                        border = "rounded",
                        winhighlight = cmp_window_hl,
                    }),
                },
                snippet = {
                    expand = function(args)
                        require("luasnip").lsp_expand(args.body)
                    end,
                },
                mapping = cmp.mapping.preset.insert({
                    ["<Tab>"] = cmp.mapping.select_next_item(),
                    ["<S-Tab>"] = cmp.mapping.select_prev_item(),
                    ["<CR>"] = cmp.mapping.confirm({ select = true }),
                }),
                sorting = {
                    priority_weight = 2,
                    comparators = {
                        function(entry1, entry2)
                            local snippet_kind = cmp_types.lsp.CompletionItemKind.Snippet
                            local entry1_is_snippet = entry1:get_kind() == snippet_kind
                            local entry2_is_snippet = entry2:get_kind() == snippet_kind
                            if entry1_is_snippet ~= entry2_is_snippet then
                                return entry1_is_snippet
                            end
                        end,
                        cmp.config.compare.offset,
                        cmp.config.compare.exact,
                        cmp.config.compare.score,
                        cmp.config.compare.recently_used,
                        cmp.config.compare.locality,
                        cmp.config.compare.kind,
                        cmp.config.compare.sort_text,
                        cmp.config.compare.length,
                        cmp.config.compare.order,
                    },
                },
                sources = cmp.config.sources({
                    {
                        name = "luasnip",
                        group_index = 1,
                    },
                    {
                        name = "nvim_lsp",
                        group_index = 1,
                        entry_filter = function(entry)
                            -- Hide plain-text items from LSP to avoid duplicate keyword noise.
                            return entry:get_kind() ~= cmp_types.lsp.CompletionItemKind.Text
                        end,
                    },
                    {
                        name = "path",
                        group_index = 2,
                    },
                    {
                        name = "buffer",
                        group_index = 2,
                        keyword_length = 3,
                    },
                }),
            })
        end,
    },
    {
        "stevearc/overseer.nvim",
        cmd = {
            "OverseerOpen",
            "OverseerRun",
            "OverseerToggle",
            "OverseerBuild",
            "OverseerQuickAction",
            "OverseerClearCache",
        },
        -- no plugin-level key mappings here; global keymaps handle overseer commands
        config = function()
            require("overseer").setup()
        end,
    },
    {
        "akinsho/toggleterm.nvim",
        version = "*",
        config = function()
            require("toggleterm").setup({
                direction = "float",
                float_opts = {
                    border = "curved",
                    winblend = 0,
                },
            })
        end,
    },
    { "mfussenegger/nvim-dap" },
    {
        "rcarriga/nvim-dap-ui",
        dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
        config = function()
            local dap, dapui = require("dap"), require("dapui")
            dapui.setup()
            dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
            dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
            dap.listeners.before.event_exited["dapui_config"] = function() dapui.close() end
        end,
    },
    { "ThePrimeagen/refactoring.nvim", config = function() require("refactoring").setup({}) end },
    {
        "RRethy/vim-illuminate",
        config = function()
            require("illuminate").configure({ providers = { "lsp", "treesitter", "regex" }, delay = 120 })
        end,
    },
    { "NvChad/nvim-colorizer.lua",           config = function() require("colorizer").setup() end },
    { "lukas-reineke/indent-blankline.nvim", main = "ibl",                                        opts = {} },
    {
        "folke/noice.nvim",
        dependencies = { "MunifTanjim/nui.nvim", "rcarriga/nvim-notify" },
        config = function()
            require("notify").setup({
                stages = "fade_in_slide_out",
                render = "compact",
                timeout = 2200,
                fps = 60,
                top_down = false,
            })

            require("noice").setup({
                lsp = { progress = { enabled = true } },
                cmdline = {
                    format = {
                        search_down = { kind = "search", pattern = "^/", icon = " ", lang = "" },
                        search_up = { kind = "search", pattern = "^%?", icon = " ", lang = "" },
                    },
                },
                views = {
                    popup = {
                        border = { style = "rounded" },
                        win_options = {
                            winblend = 0,
                            winhighlight = {
                                Normal = "NoicePopup",
                                FloatBorder = "NoicePopupBorder",
                            },
                        },
                    },
                    cmdline_popup = {
                        border = { style = "rounded" },
                        win_options = {
                            winblend = 0,
                            winhighlight = {
                                Normal = "NoiceCmdlinePopup",
                                FloatBorder = "NoiceCmdlinePopupBorder",
                                Search = "None",
                                CurSearch = "None",
                                IncSearch = "None",
                            },
                        },
                    },
                    popupmenu = {
                        border = { style = "rounded" },
                        win_options = {
                            winblend = 0,
                            winhighlight = {
                                Normal = "NoicePopupmenu",
                                FloatBorder = "NoicePopupmenuBorder",
                            },
                        },
                    },
                },
            })

            vim.notify = require("notify")
        end,
    },
    { "folke/neodev.nvim",      config = function() require("neodev").setup() end },
    -- { "goolord/alpha-nvim",     config = function() require("alpha").setup(require("alpha.themes.startify").config) end },
    { "folke/persistence.nvim", config = function() require("persistence").setup() end },
    {
        "theprimeagen/harpoon",
        branch = "harpoon2",
        dependencies = { "nvim-lua/plenary.nvim" },
        config = function()
            require("harpoon"):setup({})
        end,
    },
    {
        "tomasky/bookmarks.nvim",
        dependencies = { "nvim-telescope/telescope.nvim" },
        config = function()
            require("bookmarks").setup({})
        end,
    },
    {
        "anuvyklack/fold-preview.nvim",
        dependencies = { "anuvyklack/keymap-amend.nvim" },
        config = function()
            require("fold-preview").setup()
        end,
    },
    {
        "kkharji/sqlite.lua",
    },
    -- DAP virtual text
    {
        "theHamsta/nvim-dap-virtual-text",
        config = function()
            require("nvim-dap-virtual-text").setup()
        end,
    },
    -- markdown preview
    {
        "iamcco/markdown-preview.nvim",
        cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
        build = "cd app && npx --yes yarn install",
        ft = { "markdown" },
    },
    -- UFO folding
    {
        "kevinhwang91/nvim-ufo",
        dependencies = { "kevinhwang91/promise-async" },
        config = function()
            require("ufo").setup()
            vim.o.foldcolumn = "1"
            vim.o.foldlevel = 99
            vim.o.foldlevelstart = 99
            vim.o.foldenable = true
        end,
    },
    -- neotest
    {
        "nvim-neotest/neotest",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-treesitter/nvim-treesitter",
            "nvim-neotest/nvim-nio",
            "nvim-neotest/neotest-python",
            "Issafalcon/neotest-dotnet",
        },
        config = function()
            require("neotest").setup({ adapters = { require("neotest-python")({}), require("neotest-dotnet")({}) } })
        end,
    },
    -- ThePrimeagen's vim-be-good
    { "ThePrimeagen/vim-be-good" },
    -- {
    --     "karb94/neoscroll.nvim",
    --     config = function()
    --         local neoscroll = require("neoscroll")
    --         neoscroll.setup({
    --             hide_cursor = true,
    --             performance_mode = true,
    --         })
    --         local mappings = {
    --             ["<C-y>"] = function() neoscroll.scroll(-1, { move_cursor = false, duration = 50 }) end,
    --             ["<C-e>"] = function() neoscroll.scroll(1, { move_cursor = false, duration = 50 }) end,
    --         }
    --         for key, fn in pairs(mappings) do
    --             vim.keymap.set({ "n", "v", "x" }, key, fn, { silent = true })
    --         end
    --     end,
    -- },
    -- Database UI for vim-dadbod
    {
        "kristijanhusak/vim-dadbod-ui",
        dependencies = {
            { "tpope/vim-dadbod",                     lazy = true },
            { "kristijanhusak/vim-dadbod-completion", ft = { "sql", "mysql", "plsql" }, lazy = true },
        },
        cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection", "DBUIFindBuffer" },
        init = function()
            -- use nerd fonts for nice icons in DBUI
            vim.g.db_ui_use_nerd_fonts = 1
        end,
    },
    -- Code runner to execute files in an integrated terminal
    {
        "CRAG666/code_runner.nvim",
        dependencies = { "nvim-lua/plenary.nvim", "akinsho/toggleterm.nvim" },
        config = function()
            local lspconfig = require("lspconfig")
            require("code_runner").setup({
                mode = "toggleterm",
                focus = true,
                startinsert = false,
                filetype = {
                    c = "cd $dir && gcc $fileName -o /tmp/$fileNameWithoutExt && /tmp/$fileNameWithoutExt",
                    cpp = "cd $dir && g++ $fileName -o /tmp/$fileNameWithoutExt && /tmp/$fileNameWithoutExt",
                    cs = function()
                        local util = require("lspconfig.util")
                        local root = util.root_pattern("*.csproj")(vim.api.nvim_buf_get_name(0))
                        if root == nil then
                            return "dotnet run"
                        end
                        return "cd " .. root .. " && dotnet run"
                    end,
                    python = "python3 -u",
                    lua = "lua",
                    bash = "bash",
                    sh = "bash",
                    javascript = "node",
                    typescript = "ts-node",
                    java = { "cd $dir &&", "javac $fileName &&", "java $fileNameWithoutExt" },
                    swift = function()
                        local package_swift = vim.fn.findfile("Package.swift", ".;")
                        if package_swift ~= "" then
                            local root = vim.fn.fnamemodify(package_swift, ":h")
                            return "cd " .. vim.fn.shellescape(root) .. " && swift run"
                        end
                        return "swift " .. vim.fn.shellescape(vim.fn.expand("%:p"))
                    end,
                    rust = function()
                        -- Use cargo run if Cargo.toml exists, otherwise compile manually
                        local cargo_toml = vim.fn.findfile("Cargo.toml", ".;")
                        if cargo_toml ~= "" then
                            return "cd $dir && cargo run"
                        else
                            return "cd $dir && rustc $fileName && $dir/$fileNameWithoutExt"
                        end
                    end,
                },
            })
            -- keymaps for code runner
            vim.keymap.set("n", "<leader>rr", ":RunCode<CR>", { desc = "Run Code" })
            vim.keymap.set("n", "<leader>rf", ":RunFile<CR>", { desc = "Run File" })
            vim.keymap.set("n", "<leader>rp", ":RunProject<CR>", { desc = "Run Project" })
            vim.keymap.set("n", "<leader>rc", ":RunClose<CR>", { desc = "Close Runner" })
        end,
    },
})

-- LSP and diagnostics configuration
local cmp_caps = require("cmp_nvim_lsp").default_capabilities()

vim.diagnostic.config({
    virtual_text = {
        severity = { min = vim.diagnostic.severity.ERROR },
        source = "if_many",
        spacing = 2,
    },
    signs = { severity = { min = vim.diagnostic.severity.WARN } },
    underline = { severity = { min = vim.diagnostic.severity.WARN } },
    severity_sort = true,
    update_in_insert = false,
    float = {
        border = "rounded",
        source = "if_many",
    },
})

local lsp_util = require("lspconfig.util")

local ignored_diag_items = {}
local original_diagnostic_get = vim.diagnostic.get
local original_diagnostic_show = vim.diagnostic.show
local original_diagnostic_hide = vim.diagnostic.hide

local function diag_type_from_severity(severity)
    if severity == vim.diagnostic.severity.ERROR then
        return "E"
    end
    if severity == vim.diagnostic.severity.WARN then
        return "W"
    end
    if severity == vim.diagnostic.severity.INFO then
        return "I"
    end
    return "N"
end

local function diag_key_parts(bufnr, lnum, col, end_lnum, end_col, diag_type, text)
    return table.concat({
        tostring(bufnr or 0),
        tostring(lnum or 0),
        tostring(col or 0),
        tostring(end_lnum or 0),
        tostring(end_col or 0),
        tostring(diag_type or ""),
        tostring(text or ""),
    }, "|")
end

local function diag_key(item)
    return diag_key_parts(
        item.bufnr or 0,
        item.lnum or 0,
        item.col or 0,
        item.end_lnum or 0,
        item.end_col or 0,
        item.type or "",
        item.text or ""
    )
end

local function diag_key_from_diagnostic(bufnr, diagnostic)
    return diag_key_parts(
        bufnr,
        (diagnostic.lnum or 0) + 1,
        (diagnostic.col or 0) + 1,
        diagnostic.end_lnum and (diagnostic.end_lnum + 1) or 0,
        diagnostic.end_col and (diagnostic.end_col + 1) or 0,
        diag_type_from_severity(diagnostic.severity),
        diagnostic.message or ""
    )
end

local function filter_ignored_diagnostics(bufnr, diagnostics)
    if not diagnostics or vim.tbl_isempty(diagnostics) then
        return diagnostics
    end

    local filtered = {}
    for _, diagnostic in ipairs(diagnostics) do
        local key = diag_key_from_diagnostic(bufnr, diagnostic)
        local message = (diagnostic.message or ""):lower()
        local auto_ignored = message:match("make.-class.-static") ~= nil
        if not ignored_diag_items[key] and not auto_ignored then
            table.insert(filtered, diagnostic)
        end
    end
    return filtered
end

local function get_visible_diagnostics(bufnr, opts)
    local diagnostics = original_diagnostic_get(bufnr, opts)
    if not diagnostics or vim.tbl_isempty(diagnostics) then
        return diagnostics
    end

    local filtered = filter_ignored_diagnostics(bufnr, diagnostics)
    local seen = {}
    local deduped = {}
    for _, diagnostic in ipairs(filtered) do
        local key = diag_key_from_diagnostic(bufnr, diagnostic)
        if not seen[key] then
            seen[key] = true
            table.insert(deduped, diagnostic)
        end
    end
    return deduped
end

local function diagnostic_virtual_text_key(bufnr, diagnostic)
    return table.concat({
        tostring(bufnr or 0),
        tostring(diagnostic.lnum or 0),
        tostring(diag_type_from_severity(diagnostic.severity)),
        tostring((diagnostic.message or ""):gsub("%s+", " ")),
    }, "|")
end

local function dedupe_virtual_text_diagnostics(bufnr, diagnostics)
    if not diagnostics or vim.tbl_isempty(diagnostics) then
        return diagnostics
    end

    local seen = {}
    local deduped = {}
    for _, diagnostic in ipairs(diagnostics) do
        local key = diagnostic_virtual_text_key(bufnr, diagnostic)
        if not seen[key] then
            seen[key] = true
            table.insert(deduped, diagnostic)
        end
    end
    return deduped
end

local original_virtual_text_handler = vim.diagnostic.handlers.virtual_text
local deduped_virtual_text_namespace = vim.api.nvim_create_namespace("deduped_virtual_text_diagnostics")
local virtual_text_handler_opts = {}

local function resolve_virtual_text_opts(bufnr, opts)
    if type(opts) == "table" then
        virtual_text_handler_opts[bufnr] = vim.deepcopy(opts)
        return opts
    end

    local cached = virtual_text_handler_opts[bufnr]
    if type(cached) == "table" then
        return cached
    end

    local config = vim.diagnostic.config()
    if type(config.virtual_text) == "table" then
        return config.virtual_text
    end

    return {}
end

local function refresh_virtual_text(bufnr, opts)
    local resolved_bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
    if not resolved_bufnr or not vim.api.nvim_buf_is_valid(resolved_bufnr) then
        return
    end

    original_virtual_text_handler.hide(deduped_virtual_text_namespace, resolved_bufnr)

    -- Some servers publish identical messages for slightly different spans. Collapse those
    -- before rendering virtual text so the line only shows one inline diagnostic message.
    local diagnostics = dedupe_virtual_text_diagnostics(resolved_bufnr, get_visible_diagnostics(resolved_bufnr))
    if diagnostics and not vim.tbl_isempty(diagnostics) then
        original_virtual_text_handler.show(
            deduped_virtual_text_namespace,
            resolved_bufnr,
            diagnostics,
            resolve_virtual_text_opts(resolved_bufnr, opts)
        )
    end
end

vim.diagnostic.handlers.virtual_text = {
    show = function(_, bufnr, _, opts)
        refresh_virtual_text(bufnr, opts)
    end,
    hide = function(_, bufnr)
        refresh_virtual_text(bufnr)
    end,
}

local function refresh_buffer_diagnostics(bufnr)
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
        local visible = get_visible_diagnostics(bufnr)
        local by_namespace = {}
        for _, diagnostic in ipairs(visible) do
            local namespace = diagnostic.namespace
            if namespace then
                by_namespace[namespace] = by_namespace[namespace] or {}
                table.insert(by_namespace[namespace], diagnostic)
            end
        end

        original_diagnostic_hide(nil, bufnr)
        for namespace, diagnostics in pairs(by_namespace) do
            original_diagnostic_show(namespace, bufnr, diagnostics)
        end
        vim.cmd("redrawstatus")
    end
end

vim.diagnostic.get = function(bufnr, opts)
    local resolved_bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
    return get_visible_diagnostics(resolved_bufnr, opts)
end

vim.diagnostic.show = function(namespace, bufnr, diagnostics, opts)
    if namespace ~= nil and bufnr ~= nil then
        local resolved_bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
        if diagnostics then
            diagnostics = get_visible_diagnostics(resolved_bufnr, { namespace = namespace })
        else
            diagnostics = get_visible_diagnostics(resolved_bufnr, { namespace = namespace })
        end
        return original_diagnostic_show(namespace, resolved_bufnr, diagnostics, opts)
    end

    return original_diagnostic_show(namespace, bufnr, diagnostics, opts)
end

local ok_feline_lsp, feline_lsp = pcall(require, "feline.providers.lsp")
if ok_feline_lsp then
    feline_lsp.get_diagnostics_count = function(severity)
        return vim.tbl_count(get_visible_diagnostics(0, severity and { severity = severity } or nil))
    end

    feline_lsp.diagnostics_exist = function(severity)
        return feline_lsp.get_diagnostics_count(severity) > 0
    end
end

local function diagnostics_to_qf_items(bufnr)
    local items = {}
    local diagnostics = get_visible_diagnostics(bufnr, {
        severity = { min = vim.diagnostic.severity.WARN },
    })
    for _, d in ipairs(diagnostics) do
        local item = {
            bufnr = bufnr,
            lnum = (d.lnum or 0) + 1,
            col = (d.col or 0) + 1,
            end_lnum = d.end_lnum and (d.end_lnum + 1) or nil,
            end_col = d.end_col and (d.end_col + 1) or nil,
            text = d.message,
            type = diag_type_from_severity(d.severity),
        }
        local key = diag_key(item)
        item.user_data = { diag_key = key }
        table.insert(items, item)
    end

    table.sort(items, function(a, b)
        if a.bufnr ~= b.bufnr then
            return a.bufnr < b.bufnr
        end
        if a.lnum ~= b.lnum then
            return a.lnum < b.lnum
        end
        return (a.col or 0) < (b.col or 0)
    end)
    return items
end

local function open_buffer_diagnostics_qf()
    local qf_open = false
    for _, win in ipairs(vim.fn.getwininfo()) do
        if win.quickfix == 1 and win.loclist == 0 then
            qf_open = true
            break
        end
    end
    if qf_open then
        local qf_state = vim.fn.getqflist({ context = 1 })
        if qf_state.context and qf_state.context.kind == "buffer_diagnostics" then
            vim.cmd("cclose")
            return
        end
    end

    local bufnr = vim.api.nvim_get_current_buf()
    local items = diagnostics_to_qf_items(bufnr)
    vim.fn.setqflist({}, " ", {
        title = "Diagnostics (buffer)",
        items = items,
        context = { kind = "buffer_diagnostics", bufnr = bufnr },
    })
    vim.cmd("copen")
    if #items == 0 then
        vim.notify("No active diagnostics in current buffer", vim.log.levels.INFO)
    end
end

local function open_ignored_diagnostics_qf()
    local qf_open = false
    for _, win in ipairs(vim.fn.getwininfo()) do
        if win.quickfix == 1 and win.loclist == 0 then
            qf_open = true
            break
        end
    end
    if qf_open then
        local qf_state = vim.fn.getqflist({ context = 1 })
        if qf_state.context and qf_state.context.kind == "ignored_diagnostics" then
            vim.cmd("cclose")
            return
        end
    end

    local items = {}
    for _, item in pairs(ignored_diag_items) do
        table.insert(items, item)
    end
    table.sort(items, function(a, b)
        if a.bufnr ~= b.bufnr then
            return a.bufnr < b.bufnr
        end
        if a.lnum ~= b.lnum then
            return a.lnum < b.lnum
        end
        return (a.col or 0) < (b.col or 0)
    end)

    vim.fn.setqflist({}, " ", {
        title = "Diagnostics (ignored)",
        items = items,
        context = { kind = "ignored_diagnostics" },
    })
    vim.cmd("copen")
    if #items == 0 then
        vim.notify("No ignored diagnostics", vim.log.levels.INFO)
    end
end

local function qf_selected_range(from_visual)
    if from_visual then
        local s = vim.fn.line("'<")
        local e = vim.fn.line("'>")
        if s > e then
            s, e = e, s
        end
        return s, e
    end
    local row = vim.api.nvim_win_get_cursor(0)[1]
    return row, row
end

local function qf_is_diagnostics_context(context)
    return context and (context.kind == "buffer_diagnostics" or context.kind == "ignored_diagnostics")
end

local function qf_jump_to_selected()
    local idx = vim.api.nvim_win_get_cursor(0)[1]
    local qf = vim.fn.getqflist({ items = 1 })
    if not qf.items[idx] then
        vim.notify("No diagnostic selected", vim.log.levels.WARN)
        return false
    end
    vim.cmd("cc " .. idx)
    return true
end

local function qf_show_selected_diagnostic()
    if not qf_jump_to_selected() then
        return
    end

    vim.schedule(function()
        vim.diagnostic.open_float(nil, {
            scope = "line",
            focus = false,
            border = "rounded",
            source = "if_many",
        })
    end)
end

local function qf_show_selected_quickfixes()
    if not qf_jump_to_selected() then
        return
    end

    vim.schedule(function()
        vim.lsp.buf.code_action({
            context = { only = { "quickfix" } },
        })
    end)
end

local function qf_ignore_selected(from_visual)
    local qf = vim.fn.getqflist({ items = 1, context = 1, title = 1 })
    if not (qf.context and qf.context.kind == "buffer_diagnostics") then
        vim.notify("Open <leader>sd diagnostics list first", vim.log.levels.WARN)
        return
    end

    local start_row, end_row = qf_selected_range(from_visual)
    local kept, removed = {}, 0
    for i, item in ipairs(qf.items) do
        if i >= start_row and i <= end_row then
            local key = (item.user_data and item.user_data.diag_key) or diag_key(item)
            item.user_data = { diag_key = key }
            ignored_diag_items[key] = item
            removed = removed + 1
        else
            table.insert(kept, item)
        end
    end

    vim.fn.setqflist({}, "r", {
        title = qf.title,
        items = kept,
        context = qf.context,
    })
    vim.cmd("copen")
    refresh_buffer_diagnostics(qf.context.bufnr)
    vim.notify("Ignored " .. removed .. " diagnostic(s)", vim.log.levels.INFO)
end

local function qf_unignore_selected(from_visual)
    local qf = vim.fn.getqflist({ items = 1, context = 1, title = 1 })
    if not (qf.context and qf.context.kind == "ignored_diagnostics") then
        vim.notify("Open ignored diagnostics list first", vim.log.levels.WARN)
        return
    end

    local start_row, end_row = qf_selected_range(from_visual)
    local kept, restored = {}, 0
    local refresh_bufnrs = {}
    for i, item in ipairs(qf.items) do
        local key = (item.user_data and item.user_data.diag_key) or diag_key(item)
        if i >= start_row and i <= end_row then
            ignored_diag_items[key] = nil
            restored = restored + 1
            refresh_bufnrs[item.bufnr] = true
        else
            table.insert(kept, item)
        end
    end

    vim.fn.setqflist({}, "r", {
        title = qf.title,
        items = kept,
        context = qf.context,
    })
    vim.cmd("copen")
    for bufnr in pairs(refresh_bufnrs) do
        refresh_buffer_diagnostics(bufnr)
    end
    vim.notify("Restored " .. restored .. " diagnostic(s)", vim.log.levels.INFO)
end

local function qf_delete_selected(from_visual)
    local qf = vim.fn.getqflist({ context = 1 })
    if qf.context and qf.context.kind == "ignored_diagnostics" then
        qf_unignore_selected(from_visual)
    else
        qf_ignore_selected(from_visual)
    end
end

vim.api.nvim_create_autocmd("FileType", {
    pattern = "qf",
    callback = function(args)
        local opts = { buffer = args.buf, silent = true }
        vim.keymap.set("n", "d", function() qf_delete_selected(false) end, opts)
        vim.keymap.set("n", "dd", function() qf_delete_selected(false) end, opts)
        vim.keymap.set("x", "d", function() qf_delete_selected(true) end, opts)
        vim.keymap.set("n", "u", function() qf_unignore_selected(false) end, opts)
        vim.keymap.set("x", "u", function() qf_unignore_selected(true) end, opts)

        local qf = vim.fn.getqflist({ context = 1 })
        if qf_is_diagnostics_context(qf.context) then
            vim.keymap.set("n", "<CR>", qf_show_selected_diagnostic, opts)
            vim.keymap.set("n", "f", qf_show_selected_quickfixes, opts)
        end
    end,
})

vim.lsp.config["lua_ls"] = {
    capabilities = cmp_caps,
    settings = { Lua = { diagnostics = { globals = { "vim", "Snacks" } } } },
}
vim.lsp.config["clangd"] = { capabilities = cmp_caps }
vim.lsp.config["pyright"] = {
    capabilities = cmp_caps,
    settings = {
        python = {
            analysis = {
                typeCheckingMode = "basic",
                diagnosticMode = "openFilesOnly",
                autoSearchPaths = true,
                useLibraryCodeForTypes = true,
            },
        },
    },
}
vim.lsp.config["html"] = {
    capabilities = cmp_caps,
    filetypes = { "html" },
}
vim.lsp.config["lemminx"] = {
    capabilities = cmp_caps,
    filetypes = { "xml", "xsd", "xsl", "xslt", "svg" },
}
vim.lsp.config["sourcekit"] = {
    capabilities = cmp_caps,
    cmd = (vim.fn.executable("xcrun") == 1) and { "xcrun", "sourcekit-lsp" } or { "sourcekit-lsp" },
    root_dir = lsp_util.root_pattern("Package.swift", ".git", "*.xcodeproj", "*.xcworkspace"),
}

local enabled_lsps = { "lua_ls", "clangd", "pyright", "html", "lemminx" }
if vim.fn.executable("sourcekit-lsp") == 1 then
    table.insert(enabled_lsps, "sourcekit")
elseif vim.fn.executable("xcrun") == 1 then
    local has_sourcekit = false
    if vim.system then
        local result = vim.system({ "xcrun", "--find", "sourcekit-lsp" }, { text = true }):wait()
        has_sourcekit = result.code == 0 and type(result.stdout) == "string" and vim.trim(result.stdout) ~= ""
    else
        local output = vim.fn.system({ "xcrun", "--find", "sourcekit-lsp" })
        has_sourcekit = vim.v.shell_error == 0 and vim.trim(output) ~= ""
    end
    if has_sourcekit then
        table.insert(enabled_lsps, "sourcekit")
    end
end

vim.lsp.enable(enabled_lsps)

local function format_axaml_buffer(bufnr)
    if vim.bo[bufnr].filetype ~= "xml" then
        return false
    end

    local name = vim.api.nvim_buf_get_name(bufnr)
    if not name:match("%.axaml$") and not name:match("%.xaml$") then
        return false
    end

    local lemminx_clients = vim.lsp.get_clients({ bufnr = bufnr, name = "lemminx" })
    for _, client in ipairs(lemminx_clients) do
        if client.supports_method and client:supports_method("textDocument/formatting") then
            vim.lsp.buf.format({
                bufnr = bufnr,
                async = false,
                timeout_ms = 2000,
                filter = function(c)
                    return c.id == client.id
                end,
            })
            return true
        end
    end

    if vim.fn.executable("xmllint") ~= 1 then
        return false
    end

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local input = table.concat(lines, "\n")
    local output = ""
    local shift = vim.bo[bufnr].shiftwidth
    local indent = string.rep(" ", shift > 0 and shift or 4)

    if vim.system then
        local result = vim.system(
            { "xmllint", "--format", "-" },
            {
                text = true,
                stdin = input,
                env = vim.tbl_extend("force", vim.fn.environ(), { XMLLINT_INDENT = indent }),
            }
        ):wait()
        if result.code ~= 0 or type(result.stdout) ~= "string" or result.stdout == "" then
            return false
        end
        output = result.stdout
    else
        local old_indent = vim.env.XMLLINT_INDENT
        vim.env.XMLLINT_INDENT = indent
        output = vim.fn.system({ "xmllint", "--format", "-" }, input)
        vim.env.XMLLINT_INDENT = old_indent
        if vim.v.shell_error ~= 0 or type(output) ~= "string" or output == "" then
            return false
        end
    end

    local view = vim.fn.winsaveview()
    local formatted = vim.split(output, "\n", { plain = true })

    if formatted[#formatted] == "" then
        table.remove(formatted, #formatted)
    end

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, formatted)
    vim.fn.winrestview(view)

    return true
end

local function format_current_buffer(opts)
    local bufnr = (opts and opts.bufnr) or vim.api.nvim_get_current_buf()
    if format_axaml_buffer(bufnr) then
        return
    end
    require("conform").format({
        bufnr = bufnr,
        async = (opts and opts.async) or false,
        lsp_format = "fallback",
    })
end

local function xml_smart_newline()
    -- Reindent the new line according to xml indentexpr after newline insert.
    return "<CR><C-o>=="
end

local c_smart_brace_retry = {}
local c_smart_semicolon_retry = {}
local csharp_identifier_cache = {}
local csharp_dot_targets = {
    "System",
    "Collections",
    "Generic",
    "Linq",
    "Text",
    "Threading",
    "Tasks",
    "IO",
    "Console",
    "Debug",
    "Trace",
    "Math",
    "Convert",
    "Environment",
    "Task",
    "Enumerable",
    "DateTime",
    "TimeSpan",
    "Guid",
    "StringBuilder",
    "File",
    "Directory",
    "Path",
    "Exception",
    "InvalidOperationException",
    "ArgumentNullException",
    "List",
    "Dictionary",
    "HashSet",
    "IEnumerable",
    "TaskCompletionSource",
    "CancellationToken",
    "HttpClient",
    "JsonSerializer",
    "Regex",
    "Uri",
    "DateOnly",
    "TimeOnly",
    "Span",
    "Memory",
    "Array",
    "WriteLine",
    "Write",
    "ReadLine",
    "ToString",
    "Add",
    "Remove",
    "Select",
    "Where",
    "Any",
    "All",
    "Count",
    "First",
    "FirstOrDefault",
    "Single",
    "SingleOrDefault",
    "Last",
    "LastOrDefault",
    "Contains",
    "StartsWith",
    "EndsWith",
    "Split",
    "Join",
    "Format",
    "Parse",
    "TryParse",
    "Create",
    "Run",
    "WhenAll",
    "WhenAny",
    "ConfigureAwait",
    "Append",
    "AppendLine",
}
local c_signature_blocklist = {
    ["if"] = true,
    ["for"] = true,
    ["while"] = true,
    ["switch"] = true,
    ["return"] = true,
    ["sizeof"] = true,
}

local function undo_seq_cur()
    local tree = vim.fn.undotree()
    return tonumber(tree.seq_cur) or 0
end

local function c_identifier_before(line, pos)
    local prefix = line:sub(1, pos - 1):gsub("%s+$", "")
    return prefix:match("([%a_][%w_]*)$")
end

local function is_csharp_symbol_like_identifier(ident)
    return ident
        and ident:match("^[%a_][%w_]*$")
        and ident:match("%u")
        and not ident:match("^_+$")
end

local function should_skip_csharp_dot_autocorrect(ident)
    return not ident
        or ident:match("^[a-z][%w_]*$")
        or ident:match("^_+[a-z][%w_]*$")
end

local function is_within_one_identifier_edit(a, b)
    if a == b then
        return true
    end

    local len_a = #a
    local len_b = #b
    if math.abs(len_a - len_b) > 1 then
        return false
    end

    if len_a == len_b then
        local mismatches = {}
        for i = 1, len_a do
            if a:sub(i, i) ~= b:sub(i, i) then
                mismatches[#mismatches + 1] = i
                if #mismatches > 2 then
                    return false
                end
            end
        end
        if #mismatches == 1 then
            return true
        end
        if #mismatches == 2 then
            local i, j = mismatches[1], mismatches[2]
            return a:sub(i, i) == b:sub(j, j) and a:sub(j, j) == b:sub(i, i)
        end
        return false
    end

    local shorter = a
    local longer = b
    if len_a > len_b then
        shorter = b
        longer = a
    end

    local i, j = 1, 1
    local used_skip = false
    while i <= #shorter and j <= #longer do
        if shorter:sub(i, i) == longer:sub(j, j) then
            i = i + 1
            j = j + 1
        elseif used_skip then
            return false
        else
            used_skip = true
            j = j + 1
        end
    end

    return true
end

local function csharp_identifier_distance(a, b)
    if a == b then
        return 0
    end

    local len_a = #a
    local len_b = #b
    local prev_prev = {}
    local prev = {}
    local curr = {}

    for j = 0, len_b do
        prev[j] = j
    end

    for i = 1, len_a do
        curr[0] = i
        for j = 1, len_b do
            local cost = (a:sub(i, i) == b:sub(j, j)) and 0 or 1
            local deletion = prev[j] + 1
            local insertion = curr[j - 1] + 1
            local substitution = prev[j - 1] + cost
            local best = math.min(deletion, insertion, substitution)

            if i > 1 and j > 1
                and a:sub(i, i) == b:sub(j - 1, j - 1)
                and a:sub(i - 1, i - 1) == b:sub(j, j)
            then
                best = math.min(best, (prev_prev[j - 2] or math.huge) + 1)
            end

            curr[j] = best
        end
        prev_prev, prev, curr = prev, curr, prev_prev
    end

    return prev[len_b]
end

local function csharp_max_identifier_distance(len)
    if len <= 4 then
        return 1
    end
    if len <= 10 then
        return 2
    end
    return 3
end

local function collect_csharp_buffer_identifiers(bufnr)
    if not (vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr)) then
        return {}
    end
    if vim.bo[bufnr].filetype ~= "cs" then
        return {}
    end

    local tick = vim.api.nvim_buf_get_changedtick(bufnr)
    local cached = csharp_identifier_cache[bufnr]
    if cached and cached.tick == tick then
        return cached.identifiers
    end

    local identifiers = {}
    for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
        for ident in line:gmatch("[%a_][%w_]*") do
            if is_csharp_symbol_like_identifier(ident) then
                local key = ident:lower()
                identifiers[key] = identifiers[key] or ident
            end
        end
    end

    csharp_identifier_cache[bufnr] = {
        tick = tick,
        identifiers = identifiers,
    }
    return identifiers
end

local function csharp_dot_candidate_map(bufnr)
    local candidates = {}
    for _, ident in ipairs(csharp_dot_targets) do
        candidates[ident:lower()] = ident
    end

    for _, loaded_buf in ipairs(vim.api.nvim_list_bufs()) do
        for key, ident in pairs(collect_csharp_buffer_identifiers(loaded_buf)) do
            candidates[key] = candidates[key] or ident
        end
    end

    for key, ident in pairs(collect_csharp_buffer_identifiers(bufnr)) do
        candidates[key] = ident
    end

    return candidates
end

local function csharp_correct_dot_identifier()
    local bufnr = vim.api.nvim_get_current_buf()
    local line = vim.api.nvim_get_current_line()
    local _, col = unpack(vim.api.nvim_win_get_cursor(0))
    local prefix = line:sub(1, col)
    local ident = prefix:match("([%a_][%w_]*)$")
    if should_skip_csharp_dot_autocorrect(ident) then
        return "."
    end

    local normalized = ident:lower()
    local best_match = nil
    local best_distance = math.huge
    local max_distance = csharp_max_identifier_distance(#ident)

    for candidate_normalized, candidate in pairs(csharp_dot_candidate_map(bufnr)) do
        if candidate_normalized == normalized then
            best_match = candidate
            best_distance = 0
            break
        end

        if candidate_normalized:sub(1, 1) == normalized:sub(1, 1) then
            local distance
            if is_within_one_identifier_edit(normalized, candidate_normalized) then
                distance = 1
            else
                distance = csharp_identifier_distance(normalized, candidate_normalized)
            end

            if distance <= max_distance then
                if distance < best_distance or (distance == best_distance and #candidate < #(best_match or "")) then
                    best_match = candidate
                    best_distance = distance
                end
            end
        end
    end

    if not best_match or ident == best_match then
        return "."
    end

    local backspace = vim.api.nvim_replace_termcodes("<BS>", true, false, true)
    local undo_break = vim.api.nvim_replace_termcodes("<C-g>U", true, false, true)
    return undo_break .. string.rep(backspace, #ident) .. best_match .. "."
end

local function c_matching_open_bracket(ch)
    if ch == ")" then
        return "("
    end
    if ch == "]" then
        return "["
    end
    if ch == "}" then
        return "{"
    end
    return nil
end

local function c_unclosed_bracket_stack(line, col)
    local stack = {}
    local in_quote = nil
    local escaped = false

    for i = 1, col do
        local ch = line:sub(i, i)
        if in_quote then
            if escaped then
                escaped = false
            elseif ch == "\\" then
                escaped = true
            elseif ch == in_quote then
                in_quote = nil
            end
        else
            if ch == '"' or ch == "'" then
                in_quote = ch
            elseif ch == "(" or ch == "[" or ch == "{" then
                table.insert(stack, { char = ch, col = i })
            elseif ch == ")" or ch == "]" or ch == "}" then
                local top = stack[#stack]
                if top
                    and ((ch == ")" and top.char == "(")
                        or (ch == "]" and top.char == "[")
                        or (ch == "}" and top.char == "{"))
                then
                    table.remove(stack)
                end
            end
        end
    end

    return stack
end

local function is_c_function_parameter_context(line, col)
    if line:sub(col + 1, col + 1) ~= ")" then
        return false
    end

    local prefix = line:sub(1, col)
    if not prefix:match("%([^%(]*$") then
        return false
    end

    local before_paren = prefix:match("^(.*)%([^%(]*$")
    if not before_paren then
        return false
    end

    before_paren = before_paren:gsub("%s+$", "")
    if before_paren == "" or before_paren:match("[%]=;]$") then
        return false
    end

    local name = before_paren:match("([%a_][%w_]*)$")
    if not name or c_signature_blocklist[name] then
        return false
    end

    local before_name = before_paren:sub(1, #before_paren - #name)
    return before_name:match("%S") ~= nil
end

local function c_smart_open_brace()
    local bufnr = vim.api.nvim_get_current_buf()
    local line = vim.api.nvim_get_current_line()
    local _, col = unpack(vim.api.nvim_win_get_cursor(0))
    local npairs = require("nvim-autopairs")
    local inline_brace = npairs.autopairs_map(bufnr, "{")

    local retry = c_smart_brace_retry[bufnr]
    if retry then
        c_smart_brace_retry[bufnr] = nil
        if retry.undo_seq == undo_seq_cur() and retry.line == line and retry.col == col then
            return inline_brace
        end
    end

    if not is_c_function_parameter_context(line, col) then
        return inline_brace
    end

    c_smart_brace_retry[bufnr] = {
        undo_seq = undo_seq_cur(),
        line = line,
        col = col,
    }

    local after_paren = line:sub(col + 2, col + 2)
    local spacer = after_paren:match("%s") and "" or " "

    return vim.api.nvim_replace_termcodes("<Right>", true, false, true) .. spacer .. inline_brace
end

local function c_smart_semicolon()
    local bufnr = vim.api.nvim_get_current_buf()
    local line = vim.api.nvim_get_current_line()
    local _, col = unpack(vim.api.nvim_win_get_cursor(0))

    local retry = c_smart_semicolon_retry[bufnr]
    if retry then
        c_smart_semicolon_retry[bufnr] = nil
        if retry.undo_seq == undo_seq_cur() and retry.line == line and retry.col == col then
            return ";"
        end
    end

    local remainder = line:sub(col + 1)
    local stack = c_unclosed_bracket_stack(line, col)
    local skip_count = 0

    while true do
        local next_char = remainder:sub(skip_count + 1, skip_count + 1)
        if next_char == "" then
            break
        end

        if next_char == '"' or next_char == "'" then
            skip_count = skip_count + 1
        else
            local expected_open = c_matching_open_bracket(next_char)
            local top = stack[#stack]
            if not (expected_open and top and top.char == expected_open) then
                break
            end

            if top.char == "(" and c_identifier_before(line, top.col) == "for" then
                break
            end

            table.remove(stack)
            skip_count = skip_count + 1
        end
    end

    if skip_count == 0 then
        return ";"
    end

    c_smart_semicolon_retry[bufnr] = {
        undo_seq = undo_seq_cur(),
        line = line,
        col = col,
    }

    local move_right = vim.api.nvim_replace_termcodes("<Right>", true, false, true)
    return string.rep(move_right, skip_count) .. ";"
end

local function set_buffer_insert_expr_callback(bufnr, lhs, callback, desc)
    vim.api.nvim_buf_set_keymap(bufnr, "i", lhs, "", {
        callback = callback,
        expr = true,
        noremap = true,
        silent = true,
        desc = desc,
    })
end

local function find_xcode_container()
    local cwd = vim.fn.getcwd()
    local workspace = vim.fs.find(function(name)
        return name:match("%.xcworkspace$")
    end, { path = cwd, upward = true })[1]
    if workspace then
        return "workspace", workspace
    end
    local project = vim.fs.find(function(name)
        return name:match("%.xcodeproj$")
    end, { path = cwd, upward = true })[1]
    if project then
        return "project", project
    end
    return nil, nil
end

local function open_terminal_cmd(cmd)
    vim.cmd("botright 12split")
    vim.cmd("terminal " .. cmd)
end

local function run_xcodebuild(action, destination)
    local container_kind, container_path = find_xcode_container()
    local scheme = vim.fn.input("Xcode scheme: ")
    if scheme == "" then
        vim.notify("Xcode scheme is required", vim.log.levels.WARN)
        return
    end

    local cmd_parts = { "xcodebuild" }
    if container_kind == "workspace" then
        table.insert(cmd_parts, "-workspace")
        table.insert(cmd_parts, vim.fn.shellescape(container_path))
    elseif container_kind == "project" then
        table.insert(cmd_parts, "-project")
        table.insert(cmd_parts, vim.fn.shellescape(container_path))
    end
    table.insert(cmd_parts, "-scheme")
    table.insert(cmd_parts, vim.fn.shellescape(scheme))
    table.insert(cmd_parts, action)
    if destination and destination ~= "" then
        table.insert(cmd_parts, "-destination")
        table.insert(cmd_parts, vim.fn.shellescape(destination))
    end

    open_terminal_cmd(table.concat(cmd_parts, " "))
end

local function xcode_build_ios()
    run_xcodebuild("build", "platform=iOS Simulator,name=iPhone 16")
end

local function xcode_test_ios()
    run_xcodebuild("test", "platform=iOS Simulator,name=iPhone 16")
end

local function xcode_build_ipad()
    run_xcodebuild("build", "platform=iOS Simulator,name=iPad Pro (13-inch) (M4)")
end

local function xcode_test_ipad()
    run_xcodebuild("test", "platform=iOS Simulator,name=iPad Pro (13-inch) (M4)")
end

local function xcode_build_macos()
    run_xcodebuild("build", "platform=macOS")
end

local function xcode_test_macos()
    run_xcodebuild("test", "platform=macOS")
end

vim.api.nvim_create_user_command("XcodeBuildIOS", xcode_build_ios, {})
vim.api.nvim_create_user_command("XcodeTestIOS", xcode_test_ios, {})
vim.api.nvim_create_user_command("XcodeBuildIPad", xcode_build_ipad, {})
vim.api.nvim_create_user_command("XcodeTestIPad", xcode_test_ipad, {})
vim.api.nvim_create_user_command("XcodeBuildMac", xcode_build_macos, {})
vim.api.nvim_create_user_command("XcodeTestMac", xcode_test_macos, {})

-- Keymaps with descriptions to populate which-key
-- File explorers
vim.keymap.set("n", "<leader>e", function() require("oil").open() end, { silent = true, desc = "File Explorer (Oil)" })
-- nvim-tree toggle keymap is defined within the plugin setup, so avoid duplicating it here

-- Telescope finders
vim.keymap.set("n", "<leader>ff", function() require("telescope.builtin").find_files() end,
    { silent = true, desc = "Find Files" })
vim.keymap.set("n", "<leader>fg", function() require("telescope.builtin").live_grep() end,
    { silent = true, desc = "Grep Text" })
vim.keymap.set("n", "<leader>fb", function() require("telescope.builtin").buffers() end,
    { silent = true, desc = "Find Buffers" })
vim.keymap.set("n", "<leader>fh", function() require("telescope.builtin").help_tags() end,
    { silent = true, desc = "Help Tags" })
vim.keymap.set("n", "<leader>ft", "<cmd>TodoTelescope<CR>", { silent = true, desc = "TODOs" })
vim.keymap.set("n", "<leader>cc", choose_catppuccin_flavour, { silent = true, desc = "Choose Colour Theme" })

-- Code actions

-- LSP navigation
vim.keymap.set("n", "gd", vim.lsp.buf.definition, { silent = true, desc = "Go to Definition" })
vim.keymap.set("n", "gr", vim.lsp.buf.references, { silent = true, desc = "References" })
vim.keymap.set("n", "gi", vim.lsp.buf.implementation, { silent = true, desc = "Go to Implementation" })
-- Use lspsaga for hover documentation. The built-in hover mapping is removed to avoid conflicts
-- vim.keymap.set("n", "K", vim.lsp.buf.hover, { silent = true, desc = "Hover Info" })
local function rename_symbol()
    local bufnr = vim.api.nvim_get_current_buf()
    local filetype = vim.bo[bufnr].filetype
    local method = vim.lsp.protocol.Methods.textDocument_rename
    local clients = vim.lsp.get_clients({
        bufnr = bufnr,
        method = method,
    })

    if filetype == "cs" or filetype == "razor" then
        local roslyn_clients = vim.lsp.get_clients({
            bufnr = bufnr,
            name = "roslyn",
            method = method,
        })
        if #roslyn_clients > 0 then
            clients = roslyn_clients
        end
    end

    local client = clients[1]
    if not client then
        vim.notify("[LSP] Rename, no matching language servers with rename capability.")
        return
    end

    vim.ui.input({
        prompt = "New Name: ",
        default = vim.fn.expand("<cword>"),
    }, function(input)
        if not input or input == "" then
            return
        end

        local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
        params.newName = input
        local handler = client.handlers[method] or vim.lsp.handlers[method]

        client:request(method, params, function(...)
            handler(...)
        end, bufnr)
    end)
end

vim.keymap.set("n", "<leader>rn", rename_symbol, { silent = true, desc = "Rename Symbol" })
vim.keymap.set("n", "<leader>sd", open_buffer_diagnostics_qf, { silent = true, desc = "Diagnostics List" })
vim.keymap.set("n", "<leader>sI", open_ignored_diagnostics_qf, { silent = true, desc = "Ignored Diagnostics" })

-- Overseer tasks & Terminal toggle
vim.keymap.set("n", "<leader>tt", "<cmd>OverseerToggle<cr>", { silent = true, desc = "Tasks Panel" })

vim.keymap.set("n", "<leader>tr", "<cmd>OverseerRun<cr>", { silent = true, desc = "Run Task" })
vim.keymap.set("n", "<leader>tv", "<cmd>ToggleTerm<cr>", { silent = true, desc = "Terminal" })
vim.keymap.set("n", "<leader>xi", xcode_build_ios, { silent = true, desc = "Xcode Build iOS" })
vim.keymap.set("n", "<leader>xI", xcode_test_ios, { silent = true, desc = "Xcode Test iOS" })
vim.keymap.set("n", "<leader>xp", xcode_build_ipad, { silent = true, desc = "Xcode Build iPadOS" })
vim.keymap.set("n", "<leader>xP", xcode_test_ipad, { silent = true, desc = "Xcode Test iPadOS" })
vim.keymap.set("n", "<leader>xm", xcode_build_macos, { silent = true, desc = "Xcode Build macOS" })
vim.keymap.set("n", "<leader>xM", xcode_test_macos, { silent = true, desc = "Xcode Test macOS" })

-- Debugging (DAP)
local dap = require("dap")
vim.keymap.set("n", "<F5>", dap.continue, { desc = "Debug Continue" })
vim.keymap.set("n", "<F10>", dap.step_over, { desc = "Debug Step Over" })
vim.keymap.set("n", "<F11>", dap.step_into, { desc = "Debug Step Into" })
vim.keymap.set("n", "<F12>", dap.step_out, { desc = "Debug Step Out" })
vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "Toggle Breakpoint" })

-- Refactoring
vim.keymap.set({ "n", "x" }, "<leader>re", function() require("refactoring").refactor("Extract Function") end,
    { desc = "Extract Function" })
vim.keymap.set({ "n", "x" }, "<leader>ri", function() require("refactoring").refactor("Inline Variable") end,
    { desc = "Inline Variable" })

-- Harpoon shortcuts
vim.keymap.set("n", "<leader>ha", function() require("harpoon"):list():add() end, { desc = "Harpoon Add File" })
vim.keymap.set("n", "<leader>hm", function() require("harpoon").ui:toggle_quick_menu(require("harpoon"):list()) end,
    { desc = "Harpoon Menu" })
vim.keymap.set("n", "<leader>h1", function() require("harpoon"):list():select(1) end, { desc = "Harpoon Select 1" })
vim.keymap.set("n", "<leader>h2", function() require("harpoon"):list():select(2) end, { desc = "Harpoon Select 2" })
vim.keymap.set("n", "<leader>h3", function() require("harpoon"):list():select(3) end, { desc = "Harpoon Select 3" })
vim.keymap.set("n", "<leader>h4", function() require("harpoon"):list():select(4) end, { desc = "Harpoon Select 4" })

-- Persistence sessions
vim.keymap.set("n", "<leader>ps", "<cmd>lua require('persistence').load()<cr>", { silent = true, desc = "Load Session" })
vim.keymap.set("n", "<leader>pl", "<cmd>lua require('persistence').load({ last = true })<cr>",
    { silent = true, desc = "Load Last Session" })
vim.keymap.set("n", "<leader>pd", "<cmd>lua require('persistence').stop()<cr>",
    { silent = true, desc = "Stop Persistence" })

-- Diagnostics copy helper
vim.keymap.set("n", "<leader>zy", function()
    local diags = vim.diagnostic.get(0)
    if #diags == 0 then
        vim.notify("No diagnostics in current buffer", vim.log.levels.INFO)
        return
    end
    local lines = {}
    for _, d in ipairs(diags) do
        table.insert(lines, d.lnum + 1 .. ":" .. d.col + 1 .. " " .. d.message)
    end
    vim.fn.setreg("+", table.concat(lines, "\n"))
    vim.notify("Diagnostics copied to clipboard", vim.log.levels.INFO)
end, { desc = "Copy Diagnostics" })

-- Formatting
vim.keymap.set("n", "<leader>fa", function()
    format_current_buffer({ async = true })
end, { silent = true, desc = "Format Buffer" })

vim.keymap.set("n", "<leader>fm", function()
    format_current_buffer({ async = true })
end, { desc = "Format Buffer" })

vim.keymap.set("n", "<leader>sr", function()
    require("grug-far").open()
end, { desc = "Search and Replace" })

vim.keymap.set("v", "<leader>sr", function()
    require("grug-far").with_visual_selection()
end, { desc = "Search and Replace Selection" })

-- Database keymaps
local function dbui_open_sqlite(opts)
    local file = opts and opts.file or vim.fn.expand("%:p")
    if file == "" then
        vim.notify("No file to open", vim.log.levels.WARN)
        return
    end
    if not (file:match("%.sqlite$") or file:match("%.db$") or file:match("%.sqlite3$") or file:match("%.db3$")) then
        vim.notify("Not a SQLite file", vim.log.levels.WARN)
        return
    end
    local label = "sqlite:" .. vim.fn.fnamemodify(file, ":~")
    vim.g.dbs = vim.g.dbs or {}
    if vim.g.dbs[label] == nil then
        vim.g.dbs[label] = "sqlite:" .. file
    end
    if opts and opts.fullscreen then
        vim.cmd("tabnew")
    end
    vim.cmd("DBUI")
    if opts and opts.wipe_buf and opts.buf and vim.api.nvim_buf_is_valid(opts.buf) then
        vim.api.nvim_buf_delete(opts.buf, { force = true })
    end
end

local function reveal_in_finder()
    local path = vim.fn.expand("%:p")
    if path == "" then
        vim.notify("No file to reveal", vim.log.levels.WARN)
        return
    end
    if vim.fn.isdirectory(path) == 1 then
        vim.fn.jobstart({ "open", path }, { detach = true })
        return
    end
    if vim.fn.filereadable(path) == 0 then
        local dir = vim.fn.expand("%:p:h")
        if dir ~= "" then
            vim.fn.jobstart({ "open", dir }, { detach = true })
        else
            vim.notify("No file to reveal", vim.log.levels.WARN)
        end
        return
    end
    vim.fn.jobstart({ "open", "-R", path }, { detach = true })
end

vim.keymap.set("n", "<leader>qo", "<cmd>DBUI<CR>", { desc = "Open DBUI" })
vim.keymap.set("n", "<leader>qO", function()
    dbui_open_sqlite({ fullscreen = true, wipe_buf = true, buf = vim.api.nvim_get_current_buf() })
end, { desc = "Open DBUI (Fullscreen)" })
vim.keymap.set("n", "<leader>qc", "<cmd>DBUIClose<CR>", { desc = "Close DBUI" })
vim.keymap.set("n", "<leader>qr", "<cmd>DBUIRename<CR>", { desc = "Rename Connection" })
vim.keymap.set("n", "<leader>qs", "<cmd>DBUISaveQuery<CR>", { desc = "Save Query" })
vim.keymap.set("n", "<leader>qf", function()
    local file = vim.fn.expand("%:p")
    if file:match("%.sqlite$") or file:match("%.db$") then
        require("sqlite").open(file)
    else
        vim.notify("Not a SQLite file", vim.log.levels.WARN)
    end
end, { desc = "Open SQLite File" })
vim.keymap.set("n", "<leader>rq", "<cmd>DB<CR>", { desc = "Run SQL Query" })
vim.keymap.set("v", "<leader>rq", ":'<,'>DB<CR>", { desc = "Run SQL Query" })

vim.keymap.set("n", "<leader>of", reveal_in_finder, { desc = "Reveal in Finder" })

-- Buffer navigation keymaps
vim.keymap.set("n", "<leader>bn", "<cmd>bnext<CR>", { desc = "Next Buffer" })
vim.keymap.set("n", "<leader>bp", "<cmd>bprevious<CR>", { desc = "Prev Buffer" })
vim.keymap.set("n", "<leader>bo", "<cmd>enew<CR>", { desc = "New Buffer" })
vim.keymap.set("n", "<leader>bc", "<cmd>bdelete<CR>", { desc = "Close Buffer" })

-- Window management keymaps
-- These mappings mirror the defaults but with a leader prefix for convenience
vim.keymap.set("n", "<leader>ww", "<C-w>w", { desc = "Next Window" })
vim.keymap.set("n", "<leader>wh", "<C-w>h", { desc = "Left Window" })
vim.keymap.set("n", "<leader>wj", "<C-w>j", { desc = "Down Window" })
vim.keymap.set("n", "<leader>wk", "<C-w>k", { desc = "Up Window" })
vim.keymap.set("n", "<leader>wl", "<C-w>l", { desc = "Right Window" })
vim.keymap.set("n", "<leader>ws", "<cmd>split<CR>", { desc = "Horizontal Split" })
vim.keymap.set("n", "<leader>wv", "<cmd>vsplit<CR>", { desc = "Vertical Split" })
vim.keymap.set("n", "<leader>wq", "<C-w>q", { desc = "Close Window" })
vim.keymap.set("n", "<leader>wo", "<C-w>o", { desc = "Only Window" })
vim.keymap.set("n", "<leader>w=", "<C-w>=", { desc = "Balance Windows" })
-- Resize splits
vim.keymap.set("n", "<leader>w<", "<C-w><", { desc = "Decrease window width" })
vim.keymap.set("n", "<leader>w>", "<C-w>>", { desc = "Increase window width" })
vim.keymap.set("n", "<leader>w-", "<C-w>-", { desc = "Decrease window height" })
vim.keymap.set("n", "<leader>w+", "<C-w>+", { desc = "Increase window height" })

-- Which-key registrations
local wk = require("which-key")
wkr = require("which-key") -- alias for clarity in modifications
wkr.add({
    -- File explorer
    { "<leader>e",  function() require("oil").open() end,                     desc = "File Explorer (Oil)", icon = { icon = " ", color = "cyan" } },
    { "<leader>;",  function() require("dropbar.api").pick() end,             desc = "Pick symbols in winbar", icon = { icon = "󰉺 ", color = "blue" } },
    { "<leader>nt", function()
        local mf = require("mini.files")
        if mf.get_explorer_state() ~= nil then
            mf.close()
        else
            mf.open(vim.fn.getcwd(), true)
        end
    end, desc = "Toggle mini.files", icon = { icon = "󰉓 ", color = "cyan" } },
    -- Colors
    { "<leader>c",  group = "Colors",                                           icon = { icon = " ", color = "purple" } },
    { "<leader>cc", choose_catppuccin_flavour,                                desc = "Choose Colour Theme" },
    -- { "<leader>nt", "<cmd>NvimTreeToggle<CR>",                                desc = "Toggle Nvim Tree" },
    -- { "<leader>nt", "<cmd>Neotree toggle filesystem left<CR>",                desc = "Toggle Neo-tree" },
    { "<leader>n",  group = "Notifications",                                    icon = { icon = "󰵅 ", color = "blue" } },
    { "<leader>t",  group = "Tasks/Terminal",                                   icon = { icon = " ", color = "yellow" } },
    { "<leader>u",  group = "UI/Toggles",                                       icon = { icon = " ", color = "yellow" } },
    -- Open
    { "<leader>o",  group = "Open",                                             icon = { icon = " ", color = "cyan" } },
    { "<leader>of", reveal_in_finder,                                         desc = "Reveal in Finder" },
    -- Find
    { "<leader>f",  group = "Find",                                             icon = { icon = " ", color = "green" } },
    { "<leader>ff", function() require("telescope.builtin").find_files() end, desc = "Find Files" },
    { "<leader>fg", function() require("telescope.builtin").live_grep() end,  desc = "Grep Text" },
    { "<leader>fb", function() require("telescope.builtin").buffers() end,    desc = "Find Buffers" },
    { "<leader>fh", function() require("telescope.builtin").help_tags() end,  desc = "Help Tags" },
    { "<leader>fm", function()
        format_current_buffer({ async = true })
    end, desc = "Format Buffer" },
    { "<leader>fd", "<cmd>Telescope diagnostics<CR>",                         desc = "Diagnostics" },
    { "<leader>ft", "<cmd>TodoTelescope<CR>",                                 desc = "TODOs" },
    -- LSP
    { "<leader>s",  group = "LSP",                                              icon = { icon = " ", color = "blue" } },
    { "<leader>sg", vim.lsp.buf.definition,                                   desc = "Go to Definition" },
    { "<leader>si", vim.lsp.buf.implementation,                               desc = "Go to Implementation" },
    { "<leader>sR", vim.lsp.buf.references,                                   desc = "References" },
    { "<leader>sK", vim.lsp.buf.hover,                                        desc = "Hover Info" },
    { "<leader>sr", function()
        require("grug-far").open()
    end, desc = "Search and Replace" },
    { "<leader>sa", function() require("actions-preview").code_actions() end, desc = "Code Action" },
    { "<leader>sd", open_buffer_diagnostics_qf,                               desc = "Diagnostics List" },
    { "<leader>sI", open_ignored_diagnostics_qf,                              desc = "Ignored Diagnostics" },
    -- Provide a separate key for line diagnostics using lspsaga
    { "<leader>sl", "<cmd>Lspsaga show_line_diagnostics<CR>",                 desc = "Line Diagnostics" },
    { "<leader>ca", "<cmd>Lspsaga code_action<CR>",                           desc = "Code Action (Saga)" },
    { "<leader>sf", "<cmd>Lspsaga finder<CR>",                                desc = "LSP Finder" },
    { "<leader>fa", function()
        format_current_buffer({ async = true })
    end, desc = "Format Buffer" },
    -- Quick rename symbol
    { "<leader>rn", rename_symbol,                                            desc = "Rename Symbol" },
    -- Git
    { "<leader>g",  group = "Git",                                              icon = { icon = " ", color = "orange" } },
    { "<leader>gs", function() require("gitsigns").stage_hunk() end,          desc = "Stage Hunk" },
    { "<leader>gu", function() require("gitsigns").undo_stage_hunk() end,     desc = "Undo Stage" },
    { "<leader>gr", function() require("gitsigns").reset_hunk() end,          desc = "Reset Hunk" },
    { "<leader>gp", function() require("gitsigns").preview_hunk_inline() end, desc = "Preview Hunk" },
    { "<leader>gb", function() require("gitsigns").blame_line() end,          desc = "Blame Line" },
    { "<leader>gd", function() require("gitsigns").diffthis() end,            desc = "Diff File" },
    -- Window
    { "<leader>w",  group = "Window",                                           icon = { icon = " ", color = "blue" } },
    { "<leader>ww", "<C-w>w",                                                 desc = "Next Window" },
    { "<leader>wh", "<C-w>h",                                                 desc = "Left Window" },
    { "<leader>wj", "<C-w>j",                                                 desc = "Down Window" },
    { "<leader>wk", "<C-w>k",                                                 desc = "Up Window" },
    { "<leader>wl", "<C-w>l",                                                 desc = "Right Window" },
    { "<leader>ws", "<cmd>split<CR>",                                         desc = "Horizontal Split" },
    { "<leader>wv", "<cmd>vsplit<CR>",                                        desc = "Vertical Split" },
    { "<leader>wq", "<C-w>q",                                                 desc = "Close Window" },
    { "<leader>wo", "<C-w>o",                                                 desc = "Only Window" },
    { "<leader>w=", "<C-w>=",                                                 desc = "Balance Windows" },
    { "<leader>w<", "<C-w><",                                                 desc = "Decrease window width" },
    { "<leader>w>", "<C-w>>",                                                 desc = "Increase window width" },
    { "<leader>w-", "<C-w>-",                                                 desc = "Decrease window height" },
    { "<leader>w+", "<C-w>+",                                                 desc = "Increase window height" },
    -- Buffers (use <leader>b prefix to avoid conflicts with neotest)
    { "<leader>b",  group = "Buffers",                                          icon = { icon = "󰈔 ", color = "cyan" } },
    { "<leader>bn", "<cmd>bnext<CR>",                                         desc = "Next Buffer" },
    { "<leader>bp", "<cmd>bprevious<CR>",                                     desc = "Prev Buffer" },
    { "<leader>bo", "<cmd>enew<CR>",                                          desc = "New Buffer" },
    { "<leader>bc", "<cmd>bdelete<CR>",                                       desc = "Close Buffer" },
    -- Later additions
    { "<leader>j",  group = "Jump",                                             icon = { icon = "󰆿 ", color = "green" } },
    { "<leader>jb", desc = "Jump Back" },
    { "<leader>jf", desc = "Jump Forward" },
    { "<leader>s",  group = "LSP",                                              icon = { icon = " ", color = "blue" } },
    { "<leader>sq", desc = "Quick Fix (LSP)" },
    { "<leader>sc", desc = "Incoming Calls" },
    { "<leader>sC", desc = "Outgoing Calls" },
    { "<leader>b",  group = "Buffers",                                          icon = { icon = "󰈔 ", color = "cyan" } },
    { "<leader>bv", desc = "Vertical split with other buffer" },
    { "<leader>bh", desc = "Horizontal split with other buffer" },
    -- Harpoon bookmarks
    { "<leader>h",  group = "Harpoon",                                          icon = { icon = "󱡀 ", color = "cyan" } },
    { "<leader>ha", function() require("harpoon"):list():add() end,           desc = "Harpoon Add File" },
    {
        "<leader>hm",
        function() require("harpoon").ui:toggle_quick_menu(require("harpoon"):list()) end,
        desc = "Harpoon Menu"
    },
    { "<leader>h1", function() require("harpoon"):list():select(1) end, desc = "Harpoon Select 1" },
    { "<leader>h2", function() require("harpoon"):list():select(2) end, desc = "Harpoon Select 2" },
    { "<leader>h3", function() require("harpoon"):list():select(3) end, desc = "Harpoon Select 3" },
    { "<leader>h4", function() require("harpoon"):list():select(4) end, desc = "Harpoon Select 4" },
    -- Tasks & Terminals
    { "<leader>x",  group = "Tasks/Term",                                       icon = { icon = " ", color = "yellow" } },
    { "<leader>xt", "<cmd>OverseerToggle<CR>",                          desc = "Tasks Panel" },
    { "<leader>xr", "<cmd>OverseerRun<CR>",                             desc = "Run Task" },
    { "<leader>xv", "<cmd>ToggleTerm<CR>",                              desc = "Terminal" },
    { "<leader>xi", xcode_build_ios,                                    desc = "Xcode Build iOS" },
    { "<leader>xI", xcode_test_ios,                                     desc = "Xcode Test iOS" },
    { "<leader>xp", xcode_build_ipad,                                   desc = "Xcode Build iPadOS" },
    { "<leader>xP", xcode_test_ipad,                                    desc = "Xcode Test iPadOS" },
    { "<leader>xm", xcode_build_macos,                                  desc = "Xcode Build macOS" },
    { "<leader>xM", xcode_test_macos,                                   desc = "Xcode Test macOS" },
    { "<leader>tt", "<cmd>OverseerToggle<cr>",                          desc = "Tasks Panel" },
    { "<leader>tr", "<cmd>OverseerRun<cr>",                             desc = "Run Task" },
    { "<leader>tv", "<cmd>ToggleTerm<cr>",                              desc = "Terminal" },
    -- Run group (code runner)
    { "<leader>r",  group = "Run",                                              icon = { icon = "󰑮 ", color = "green" } },
    { "<leader>rr", ":RunCode<CR>",                                     desc = "Run Code" },
    { "<leader>rf", ":RunFile<CR>",                                     desc = "Run File" },
    { "<leader>rp", ":RunProject<CR>",                                  desc = "Run Project" },
    { "<leader>rc", ":RunClose<CR>",                                    desc = "Close Runner" },
    { "<leader>rq", "<cmd>DB<CR>",                                      desc = "Run SQL Query" },
    { "<leader>rd", "<cmd>Dotnet run<CR>",                              desc = "Dotnet Run Project" },
    -- Refactoring helpers
    {
        "<leader>re",
        function() require("refactoring").refactor("Extract Function") end,
        desc = "Extract Function"
    },
    {
        "<leader>ri",
        function() require("refactoring").refactor("Inline Variable") end,
        desc = "Inline Variable"
    },
    -- Tests
    { "<leader>T",  group = "Tests",                                            icon = { icon = " ", color = "green" } },
    { "<leader>tn", function() require("neotest").run.run() end,                   desc = "Run nearest test" },
    { "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Run file tests" },
    { "<leader>to", function() require("neotest").output.open() end,               desc = "Test Output" },
    { "<leader>ts", function() require("neotest").summary.toggle() end,            desc = "Test Summary" },
    -- Database
    { "<leader>q",  group = "Database",                                         icon = { icon = "󰆼 ", color = "blue" } },
    { "<leader>qo", "<cmd>DBUI<CR>",                                               desc = "Open DBUI" },
    {
        "<leader>qO",
        function() dbui_open_sqlite({ fullscreen = true, wipe_buf = true, buf = vim.api.nvim_get_current_buf() }) end,
        desc = "Open DBUI (Fullscreen)"
    },
    { "<leader>qc", "<cmd>DBUIClose<CR>",     desc = "Close DBUI" },
    { "<leader>qr", "<cmd>DBUIRename<CR>",    desc = "Rename Connection" },
    { "<leader>qs", "<cmd>DBUISaveQuery<CR>", desc = "Save Query" },
    {
        "<leader>qf",
        function()
            local file = vim.fn.expand("%:p")
            if file:match("%.sqlite$") or file:match("%.db$") then
                require("sqlite").open(file)
            else
                vim.notify("Not a SQLite file", vim.log.levels.WARN)
            end
        end,
        desc = "Open SQLite File"
    },
    -- Markdown
    { "<leader>m",  group = "Markdown",                                         icon = { icon = " ", color = "blue" } },
    { "<leader>mp", "<cmd>MarkdownPreviewToggle<CR>",                  desc = "MD Preview" },
    -- Folding
    { "zR",         function() require("ufo").openAllFolds() end,      desc = "Open all folds" },
    { "zM",         function() require("ufo").closeAllFolds() end,     desc = "Close all folds" },
    -- Debug
    { "<leader>d",  group = "Debug",                                            icon = { icon = " ", color = "red" } },
    { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Toggle Breakpoint" },
    { "<leader>dc", function() require("dap").continue() end,          desc = "Continue Debug" },
    { "<leader>do", function() require("dap").step_over() end,         desc = "Step Over" },
    { "<leader>di", function() require("dap").step_into() end,         desc = "Step Into" },
    { "<leader>dO", function() require("dap").step_out() end,          desc = "Step Out" },
    -- Utilities
    { "<leader>z",  group = "Folds",                                            icon = { icon = "󰘖 ", color = "yellow" } },
    { "z<leader>a", desc = "Toggle Fold" },
    { "<leader>zo", desc = "Open Fold" },
    { "<leader>zc", desc = "Close Fold" },
    { "<leader>zR", desc = "Open All Folds" },
    { "<leader>zM", desc = "Close All Folds" },
    {
        "<leader>zy",
        function()
            local diags = vim.diagnostic.get(0)
            if #diags == 0 then
                vim.notify("No diagnostics in current buffer", vim.log.levels.INFO)
                return
            end
            local lines = {}
            for _, d in ipairs(diags) do
                table.insert(lines, (d.lnum + 1) .. ":" .. (d.col + 1) .. " " .. d.message)
            end
            vim.fn.setreg("+", table.concat(lines, "\n"))
            vim.notify("Diagnostics copied to clipboard", vim.log.levels.INFO)
        end,
        desc = "Copy Diagnostics"
    },
    -- Persistence session shortcuts
    { "<leader>p",  group = "Persistence",                                      icon = { icon = " ", color = "azure" } },
    { "<leader>ps", "<cmd>lua require('persistence').load()<cr>",                desc = "Load Session" },
    { "<leader>pl", "<cmd>lua require('persistence').load({ last = true })<cr>", desc = "Load Last Session" },
    { "<leader>pd", "<cmd>lua require('persistence').stop()<cr>",                desc = "Stop Persistence" },
    -- Notifications
    -- { "<leader>nn",  group = "Notifications" },
    -- { "<leader>nn", "<cmd>Notifications<CR>",                                    desc = "Show Notifications" },
    { "<leader>no", "<cmd>noh<CR>",                                              desc = "Hide Finds" },
    { "<leader>ud", desc = "Toggle Diagnostics" },
    { "<leader>ul", desc = "Toggle Line Numbers" },
    { "<leader>uL", desc = "Toggle Relative Number" },
    { "<leader>us", desc = "Toggle Spelling" },
    { "<leader>uw", desc = "Toggle Wrap" },
    { "<leader>uc", desc = "Toggle Conceal" },
    { "<leader>uT", desc = "Toggle Treesitter" },
    { "<leader>ub", desc = "Toggle Background" },
    { "<leader>uh", desc = "Toggle Inlay Hints" },
    { "<leader>ug", desc = "Toggle Indent Guides" },
    { "<leader>uD", desc = "Toggle Dim" },
    { "<leader>un", desc = "Dismiss Notifications" },
    { "<leader>uC", desc = "Choose Colorscheme" },
    -- Misc
    { "s",          group = "Flash",                                            icon = { icon = " ", color = "yellow" } },
    { "]d",         desc = "Next Diagnostic" },
    { "[d",         desc = "Prev Diagnostic" },
    { "za",         desc = "Toggle Fold" },
    { "zc",         desc = "Close Fold" },
    { "zo",         desc = "Open Fold" },
})
vim.keymap.set({ "n", "x", "o" }, "s", function()
    require("flash").jump()
end, { desc = "Flash Jump" })
-- lspsaga
vim.keymap.set("n", "K", "<cmd>Lspsaga hover_doc<CR>", { desc = "Hover (Lspsaga)" })
vim.keymap.set("n", "<leader>ca", "<cmd>Lspsaga code_action<CR>", { desc = "Code Action" })
-- Map line diagnostics to <leader>sl instead of overriding <leader>sd
vim.keymap.set("n", "<leader>sl", "<cmd>Lspsaga show_line_diagnostics<CR>", { desc = "Line Diagnostics" })
vim.keymap.set("n", "<leader>sf", "<cmd>Lspsaga finder<CR>", { desc = "LSP Finder" })
-- Dotnet running
vim.keymap.set("n", "<leader>rd", "<cmd>Dotnet run<CR>", { desc = "Dotnet Run Project" })

-- Auto-open SQLite files in DBUI and close the raw buffer
vim.api.nvim_create_autocmd("BufReadPost", {
    pattern = { "*.sqlite", "*.db", "*.sqlite3", "*.db3" },
    callback = function(args)
        dbui_open_sqlite({ fullscreen = true, wipe_buf = true, buf = args.buf, file = args.file })
    end,
})

-- Per-language tab/space behaviour
vim.api.nvim_create_autocmd("FileType", {
    pattern = { "cpp", "c", "cs", "python", "lua", "javascript", "typescript", "swift" },
    callback = function(ev)
        local ft = vim.bo[ev.buf].filetype
        if ft == "cpp" or ft == "c" then
            vim.bo.tabstop = 2
            vim.bo.shiftwidth = 2
            vim.bo.softtabstop = 2
            vim.bo.expandtab = true
            set_buffer_insert_expr_callback(ev.buf, "{", c_smart_open_brace, "Smart open brace")
            set_buffer_insert_expr_callback(ev.buf, ";", c_smart_semicolon, "Smart semicolon")
        elseif ft == "cs" then
            vim.bo.tabstop = 4
            vim.bo.shiftwidth = 4
            vim.bo.softtabstop = 4
            vim.bo.expandtab = true
            set_buffer_insert_expr_callback(ev.buf, "{", c_smart_open_brace, "Smart open brace")
            set_buffer_insert_expr_callback(ev.buf, ";", c_smart_semicolon, "Smart semicolon")
            set_buffer_insert_expr_callback(ev.buf, ".", csharp_correct_dot_identifier, "Smart C# dot correction")
        elseif ft == "python" then
            vim.bo.tabstop = 4
            vim.bo.shiftwidth = 4
            vim.bo.softtabstop = 4
            vim.bo.expandtab = true
        elseif ft == "swift" then
            vim.bo.tabstop = 4
            vim.bo.shiftwidth = 4
            vim.bo.softtabstop = 4
            vim.bo.expandtab = true
        end
    end,
})

vim.api.nvim_create_autocmd("FileType", {
    pattern = "xml",
    callback = function(ev)
        vim.bo[ev.buf].autoindent = true
        vim.bo[ev.buf].smartindent = false
        vim.bo[ev.buf].cindent = false
        vim.keymap.set("i", "<CR>", xml_smart_newline, {
            buffer = ev.buf,
            expr = true,
            silent = true,
            replace_keycodes = true,
        })
    end,
})
-- vim.keymap.set("n", "<leader>nn", "<cmd>Notifications<CR>", { desc = "Show Notifications" })
vim.keymap.set("n", "<leader>no", "<cmd>noh<CR>", { desc = "Hide Finds" })
-----------------------------------------------------------
-- Buffer-based splitting: choose a buffer to split with
-----------------------------------------------------------

-- Ask for a buffer number, then vertical split and load it
vim.keymap.set("n", "<leader>bV", function()
    local buf = tonumber(vim.fn.input("Buffer number: "))
    if not buf or vim.fn.bufexists(buf) == 0 then
        vim.notify("Invalid buffer", vim.log.levels.ERROR)
        return
    end
    vim.cmd("vsplit")
    vim.cmd("buffer " .. buf)
end, { desc = "Vertical split with chosen buffer" })

-- Ask for a buffer number, then horizontal split and load it
vim.keymap.set("n", "<leader>bH", function()
    local buf = tonumber(vim.fn.input("Buffer number: "))
    if not buf or vim.fn.bufexists(buf) == 0 then
        vim.notify("Invalid buffer", vim.log.levels.ERROR)
        return
    end
    vim.cmd("split")
    vim.cmd("buffer " .. buf)
end, { desc = "Horizontal split with chosen buffer" })

vim.keymap.set("n", "<leader>fk", function()
    require("telescope.builtin").keymaps()
end, { desc = "Find Keymaps" })

vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { desc = "Go to Declaration" })
vim.keymap.set("n", "gt", vim.lsp.buf.type_definition, { desc = "Go to Type Definition" })

-----------------------------------------------------------
-- CLion-like upgrades: clangd + quickfix + DAP + safer splits
-----------------------------------------------------------

-- 1) clangd: keep defaults for a normal (less noisy) diagnostics profile
vim.lsp.config["clangd"] = { capabilities = cmp_caps }

-- 2) LSP "Quick Fix" (only) + apply-first helper
-- Shows only quickfix actions (when servers provide them).
vim.keymap.set("n", "<leader>sq", function()
    vim.lsp.buf.code_action({
        context = { only = { "quickfix" } },
    })
end, { desc = "Quick Fix (LSP)" })

-- Put current-file diagnostics into the quickfix list (handy CLion-style workflow)
vim.keymap.set("n", "<leader>sd", function()
    open_buffer_diagnostics_qf()
end, { desc = "Diagnostics List" })

-- 3) Call hierarchy (CLion-ish)
-- You already have lspsaga installed; these are its call hierarchy commands.
vim.keymap.set("n", "<leader>sc", "<cmd>Lspsaga incoming_calls<CR>", { desc = "Incoming Calls" })
vim.keymap.set("n", "<leader>sC", "<cmd>Lspsaga outgoing_calls<CR>", { desc = "Outgoing Calls" })

-- 4) Navigation back/forward (jump list) with leader keys (optional convenience)
vim.keymap.set("n", "<leader>jb", "<C-o>", { desc = "Jump Back" })
vim.keymap.set("n", "<leader>jf", "<C-i>", { desc = "Jump Forward" })

-- 5) Safer buffer splitting:
-- Use prev buffer if valid; otherwise pick another listed buffer. Works after restart.
-- Remove your old bv/bh splitting section before using this.
local _prev_buf = nil
vim.api.nvim_create_autocmd("BufLeave", {
    callback = function(args)
        _prev_buf = args.buf
    end,
})

local function _pick_other_listed_buffer(current, preferred)
    local function ok(buf)
        return buf
            and vim.api.nvim_buf_is_valid(buf)
            and vim.bo[buf].buflisted
            and buf ~= current
    end
    if ok(preferred) then
        return preferred
    end
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if ok(b) then
            return b
        end
    end
    return nil
end

local function _split_with_other(direction)
    local cur = vim.api.nvim_get_current_buf()
    local target = _pick_other_listed_buffer(cur, _prev_buf)
    if not target then
        vim.notify("No other buffer to split with", vim.log.levels.WARN)
        return
    end
    vim.cmd(direction == "v" and "vsplit" or "split")
    vim.cmd("buffer " .. target)
end

vim.keymap.set("n", "<leader>bv", function() _split_with_other("v") end, { desc = "Vertical split with other buffer" })
vim.keymap.set("n", "<leader>bh", function() _split_with_other("h") end, { desc = "Horizontal split with other buffer" })

-- DAP adapters (simple + Mason-compatible)
local dap_ok, dap_mod = pcall(require, "dap")
if dap_ok then
    -- codelldb (C / C++ / Rust)
    dap_mod.adapters.codelldb = {
        type = "server",
        port = "${port}",
        executable = {
            command = "codelldb", -- Mason puts this on PATH
            args = { "--port", "${port}" },
        },
    }
    dap_mod.configurations.cpp = {
        {
            name = "Debug (codelldb)",
            type = "codelldb",
            request = "launch",
            program = function()
                return vim.fn.input(
                    "Path to executable: ",
                    vim.fn.getcwd() .. "/",
                    "file"
                )
            end,
            cwd = "${workspaceFolder}",
            stopOnEntry = false,
        },
    }
    dap_mod.configurations.c = dap_mod.configurations.cpp
    -- netcoredbg (.NET)
    dap_mod.adapters.coreclr = {
        type = "executable",
        command = "netcoredbg", -- Mason puts this on PATH
        args = { "--interpreter=vscode" },
    }
    dap_mod.configurations.cs = {
        {
            name = "Debug (.NET)",
            type = "coreclr",
            request = "launch",
            program = function()
                return vim.fn.input(
                    "Path to dll: ",
                    vim.fn.getcwd() .. "/bin/Debug/",
                    "file"
                )
            end,
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
end

-- Folding
vim.keymap.set("n", "<leader>uf", function()
    vim.o.foldcolumn = vim.o.foldcolumn == "0" and "1" or "0"
end, { desc = "Toggle Fold Column" })


-- vim.api.nvim_create_autocmd("VimEnter", {
--   callback = function()
--     if vim.fn.argc() == 0 then
--       Snacks.dashboard()
--     end
--   end,
-- })
--

vim.g.lazyvim_starter = false

vim.ui.input = Snacks.input
vim.ui.select = Snacks.picker.select

local function close_buffer_force(bufnr)
    if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end

    if vim.bo[bufnr].buftype == "terminal" then
        vim.cmd("silent! bwipeout! " .. bufnr)
        return
    end

    vim.cmd("silent! bdelete " .. bufnr)
end

local function pick_close_buffer()
    require("bufferline.pick").choose_then(close_buffer_force)
end

vim.keymap.set("n", "<leader>nt", function()
    local mf = require("mini.files")
    if mf.get_explorer_state() ~= nil then
        mf.close()
    else
        mf.open(vim.fn.getcwd(), true)
    end
end, { desc = "Toggle mini.files" })

vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
        if vim.fn.argc() ~= 1 then
            return
        end

        local arg = vim.fn.argv(0)
        if vim.fn.isdirectory(arg) ~= 1 then
            return
        end

        vim.schedule(function()
            pcall(vim.cmd, "silent! bwipeout 1")
            require("oil").open(arg)
        end)
    end,
})


vim.keymap.set("n", "<leader>bi", "<Cmd>BufferLineTogglePin<CR>", { desc = "Pin/Unpin Buffer" })
vim.keymap.set("n", "<leader>be", "<Cmd>BufferLinePick<CR>", { desc = "Pick Buffer (Jump)" })
vim.keymap.set("n", "<leader>bC", pick_close_buffer, { desc = "Pick Buffer to Close" })
