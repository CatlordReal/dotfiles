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


-- Linux build keeps theme selection local to Neovim; no desktop or terminal sync.
local CATPPUCCIN_DEFAULT_THEME = "mocha"

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

local dashboard_cat_frame = 1
local dashboard_cat_timer = nil
local dashboard_cat_frames = {
    [=[
        /\_/\\
       ( o.o )
      / > ^ <\
     /_/     \_\
]=],
    [=[
        /\_/\\
       ( -.- )
    _ / > ^ <\
     \_/     \_\
]=],
    [=[
        /\_/\\
       ( o.o )
      / > ^ <\ _
     /_/     \_/
]=],
    [=[
        /\_/\\
       ( ^.^ )
      / > ^ <\
     /_/     \_\
]=],
}

local function apply_dashboard_cat_highlights()
    vim.api.nvim_set_hl(0, "DashboardCatSprite", { fg = "#f9e2af", bold = true })
    vim.api.nvim_set_hl(0, "DashboardCatCaption", { fg = "#89b4fa", italic = true })
end

local function dashboard_cat_section()
    return {
        {
            text = {
                {
                    dashboard_cat_frames[dashboard_cat_frame],
                    hl = "DashboardCatSprite",
                },
            },
            align = "center",
        },
        {
            text = {
                {
                    "cat powered config",
                    hl = "DashboardCatCaption",
                },
            },
            align = "center",
            padding = { 1, 0 },
        },
    }
end

local function dashboard_has_visible_buffer()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf)
            and vim.bo[buf].filetype == "snacks_dashboard"
            and #vim.fn.win_findbuf(buf) > 0
        then
            return true
        end
    end
    return false
end

local function stop_dashboard_cat_animation()
    if dashboard_cat_timer then
        dashboard_cat_timer:stop()
        dashboard_cat_timer:close()
        dashboard_cat_timer = nil
    end
end

local function start_dashboard_cat_animation()
    if dashboard_cat_timer then
        return
    end

    dashboard_cat_timer = vim.uv.new_timer()
    if not dashboard_cat_timer then
        return
    end

    dashboard_cat_timer:start(450, 450, vim.schedule_wrap(function()
        if not dashboard_has_visible_buffer() then
            stop_dashboard_cat_animation()
            return
        end
        dashboard_cat_frame = (dashboard_cat_frame % #dashboard_cat_frames) + 1
        vim.api.nvim_exec_autocmds("User", { pattern = "SnacksDashboardUpdate", modeline = false })
    end))
end

apply_dashboard_cat_highlights()
vim.api.nvim_create_autocmd("ColorScheme", {
    callback = apply_dashboard_cat_highlights,
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
            local function mini_files_open_background(close_tree)
                local mf = require("mini.files")
                local entry = mf.get_fs_entry()
                if not entry then
                    return
                end

                if entry.fs_type == "directory" then
                    mf.go_in()
                    return
                end

                if entry.fs_type == "file" then
                    vim.cmd("badd " .. vim.fn.fnameescape(entry.path))
                    if close_tree then
                        mf.close()
                    end
                end
            end

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

            vim.api.nvim_create_autocmd("User", {
                pattern = "MiniFilesBufferCreate",
                callback = function(args)
                    local opts = { buffer = args.data.buf_id, nowait = true, silent = true }
                    vim.keymap.set("n", "<S-CR>", function()
                        require("mini.files").go_in({ close_on_file = true })
                    end, vim.tbl_extend("force", opts, { desc = "Open and close tree" }))
                    vim.keymap.set("n", "<Tab>", function()
                        mini_files_open_background(false)
                    end, vim.tbl_extend("force", opts, { desc = "Open in background" }))
                    vim.keymap.set("n", "<S-Tab>", function()
                        mini_files_open_background(true)
                    end, vim.tbl_extend("force", opts, { desc = "Open in background and close tree" }))
                end,
            })
        end,
    },
    {
        "nvim-neo-tree/neo-tree.nvim",
        branch = "v3.x",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-tree/nvim-web-devicons",
            "MunifTanjim/nui.nvim",
        },
        cmd = { "Neotree" },
        keys = {
            { "<leader>nt", false },
        },
        opts = {
            close_if_last_window = true,
            enable_git_status = true,
            enable_diagnostics = true,
            commands = {
                open_and_close_tree = function(state)
                    local node = state.tree:get_node()
                    if not node then
                        return
                    end
                    if node.type == "directory" then
                        require("neo-tree.sources.filesystem.commands").toggle_node(state)
                        return
                    end
                    require("neo-tree.sources.filesystem.commands").open(state)
                    vim.cmd("Neotree close")
                end,
                open_background = function(state)
                    local node = state.tree:get_node()
                    if not node then
                        return
                    end
                    if node.type == "directory" then
                        require("neo-tree.sources.filesystem.commands").toggle_node(state)
                        return
                    end
                    local path = node.path or node:get_id()
                    if path and path ~= "" then
                        vim.cmd("badd " .. vim.fn.fnameescape(path))
                    end
                end,
                open_background_and_close_tree = function(state)
                    local node = state.tree:get_node()
                    if not node then
                        return
                    end
                    if node.type == "directory" then
                        require("neo-tree.sources.filesystem.commands").toggle_node(state)
                        return
                    end
                    local path = node.path or node:get_id()
                    if path and path ~= "" then
                        vim.cmd("badd " .. vim.fn.fnameescape(path))
                    end
                    vim.cmd("Neotree close")
                end,
            },
            filesystem = {
                follow_current_file = {
                    enabled = true,
                },
                filtered_items = {
                    visible = true,
                    hide_dotfiles = false,
                    hide_gitignored = false,
                },
                use_libuv_file_watcher = true,
            },
            window = {
                width = 34,
                mappings = {
                    ["<cr>"] = "open",
                    ["<S-CR>"] = "open_and_close_tree",
                    ["<Tab>"] = "open_background",
                    ["<S-Tab>"] = "open_background_and_close_tree",
                },
            },
        },
    },
    {
        "backdround/global-note.nvim",
        cmd = { "GlobalNote", "ProjectNote" },
        keys = {
            {
                "<leader>ng",
                function() require("global-note").toggle_note() end,
                desc = "Global Note",
            },
            {
                "<leader>np",
                function() require("global-note").toggle_note("project_local") end,
                desc = "Project Note",
            },
        },
        config = function()
            local global_note = require("global-note")
            local notes_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "global-note")
            local note_float_config = nil

            local function sanitize_note_name(value)
                value = tostring(value or ""):gsub("\\", "/"):gsub("^%s+", ""):gsub("%s+$", "")
                value = value:gsub("[^%w%._%-/]", "-"):gsub("/", "%%")
                value = value:gsub("%-+", "-"):gsub("%%+", "%%")
                if value == "" then
                    return "project"
                end
                return value
            end

            local function get_project_root()
                local result = vim.system({ "git", "rev-parse", "--show-toplevel" }, { text = true }):wait()
                if result.code == 0 and type(result.stdout) == "string" and vim.trim(result.stdout) ~= "" then
                    return vim.trim(result.stdout)
                end
                return vim.loop.cwd() or vim.fn.getcwd()
            end

            local function project_note_filename()
                return sanitize_note_name(get_project_root()) .. ".md"
            end

            local function project_note_title()
                return "Project note: " .. (vim.fs.basename(get_project_root()) or "project")
            end

            local function clamp_note_config(config)
                local ui = vim.api.nvim_list_uis()[1] or { width = vim.o.columns, height = vim.o.lines }
                local max_width = math.max(40, ui.width - 4)
                local max_height = math.max(10, ui.height - 4)

                config.width = math.max(40, math.min(tonumber(config.width) or 80, max_width))
                config.height = math.max(10, math.min(tonumber(config.height) or 20, max_height))
                config.row = math.max(0, math.min(tonumber(config.row) or 1, ui.height - config.height - 2))
                config.col = math.max(0, math.min(tonumber(config.col) or 1, ui.width - config.width - 2))
                config.row = math.floor(config.row)
                config.col = math.floor(config.col)
                config.width = math.floor(config.width)
                config.height = math.floor(config.height)
                return config
            end

            local function default_note_config(title)
                local ui = vim.api.nvim_list_uis()[1] or { width = vim.o.columns, height = vim.o.lines }
                local width = math.floor(ui.width * 0.62)
                local height = math.floor(ui.height * 0.7)
                return clamp_note_config({
                    relative = "editor",
                    style = "minimal",
                    border = "rounded",
                    title = title,
                    title_pos = "center",
                    width = width,
                    height = height,
                    row = math.floor((ui.height - height) / 2),
                    col = math.floor((ui.width - width) / 2),
                })
            end

            local function note_window_config(title)
                local config = vim.deepcopy(note_float_config or default_note_config(title))
                config.relative = "editor"
                config.style = "minimal"
                config.border = "rounded"
                config.title = title
                config.title_pos = "center"
                return clamp_note_config(config)
            end

            local function is_note_window(win)
                return win and vim.api.nvim_win_is_valid(win) and vim.w[win].global_note_float == true
            end

            local function update_note_window(win, updates)
                win = win or vim.api.nvim_get_current_win()
                if not is_note_window(win) then
                    return
                end

                local config = vim.api.nvim_win_get_config(win)
                config.row = (tonumber(config.row) or 0) + (updates.row or 0)
                config.col = (tonumber(config.col) or 0) + (updates.col or 0)
                config.width = (tonumber(config.width) or 80) + (updates.width or 0)
                config.height = (tonumber(config.height) or 20) + (updates.height or 0)
                config = clamp_note_config(config)
                vim.api.nvim_win_set_config(win, config)
                note_float_config = vim.deepcopy(config)
            end

            local function note_move_mode()
                local win = vim.api.nvim_get_current_win()
                if not is_note_window(win) then
                    return
                end

                vim.notify("Note move mode: h/j/k/l move, H/J/K/L resize, q or Esc exits", vim.log.levels.INFO)
                while vim.api.nvim_win_is_valid(win) do
                    local key = vim.fn.getcharstr()
                    if key == "q" or key == "\27" then
                        break
                    elseif key == "h" then
                        update_note_window(win, { col = -4 })
                    elseif key == "j" then
                        update_note_window(win, { row = 2 })
                    elseif key == "k" then
                        update_note_window(win, { row = -2 })
                    elseif key == "l" then
                        update_note_window(win, { col = 4 })
                    elseif key == "H" then
                        update_note_window(win, { width = -4 })
                    elseif key == "J" then
                        update_note_window(win, { height = 2 })
                    elseif key == "K" then
                        update_note_window(win, { height = -2 })
                    elseif key == "L" then
                        update_note_window(win, { width = 4 })
                    end
                end
            end

            local function configure_note_buffer(buf, win)
                vim.w[win].global_note_float = true
                vim.bo[buf].filetype = "markdown"
                vim.bo[buf].buflisted = false
                vim.bo[buf].swapfile = false
                vim.wo[win].number = false
                vim.wo[win].relativenumber = false
                vim.wo[win].signcolumn = "no"
                vim.wo[win].wrap = true
                vim.wo[win].linebreak = true
                vim.wo[win].conceallevel = 2
                vim.wo[win].winhighlight = "Normal:GlobalNoteNormal,FloatBorder:GlobalNoteBorder,FloatTitle:GlobalNoteTitle"

                local opts = { buffer = buf, silent = true }
                vim.keymap.set("n", "<C-h>", function() update_note_window(win, { col = -4 }) end,
                    vim.tbl_extend("force", opts, { desc = "Move note left" }))
                vim.keymap.set("n", "<C-j>", function() update_note_window(win, { row = 2 }) end,
                    vim.tbl_extend("force", opts, { desc = "Move note down" }))
                vim.keymap.set("n", "<C-k>", function() update_note_window(win, { row = -2 }) end,
                    vim.tbl_extend("force", opts, { desc = "Move note up" }))
                vim.keymap.set("n", "<C-l>", function() update_note_window(win, { col = 4 }) end,
                    vim.tbl_extend("force", opts, { desc = "Move note right" }))
                vim.keymap.set("n", "<M-h>", function() update_note_window(win, { width = -4 }) end,
                    vim.tbl_extend("force", opts, { desc = "Narrow note" }))
                vim.keymap.set("n", "<M-j>", function() update_note_window(win, { height = 2 }) end,
                    vim.tbl_extend("force", opts, { desc = "Taller note" }))
                vim.keymap.set("n", "<M-k>", function() update_note_window(win, { height = -2 }) end,
                    vim.tbl_extend("force", opts, { desc = "Shorter note" }))
                vim.keymap.set("n", "<M-l>", function() update_note_window(win, { width = 4 }) end,
                    vim.tbl_extend("force", opts, { desc = "Widen note" }))
                vim.keymap.set("n", "<leader>nm", note_move_mode,
                    vim.tbl_extend("force", opts, { desc = "Note move mode" }))

                vim.schedule(function()
                    if vim.api.nvim_buf_is_valid(buf) then
                        vim.api.nvim_buf_call(buf, function()
                            pcall(function() require("render-markdown").buf_enable() end)
                        end)
                    end
                end)
            end

            vim.api.nvim_set_hl(0, "GlobalNoteNormal", { bg = "NONE" })
            vim.api.nvim_set_hl(0, "GlobalNoteBorder", { fg = "#89b4fa", bg = "NONE" })
            vim.api.nvim_set_hl(0, "GlobalNoteTitle", { fg = "#f9e2af", bold = true })

            global_note.setup({
                filename = "global.md",
                directory = notes_dir,
                title = "Global notes",
                command_name = "GlobalNote",
                window_config = function()
                    return note_window_config("Global notes")
                end,
                post_open = configure_note_buffer,
                autosave = true,
                additional_presets = {
                    project_local = {
                        filename = project_note_filename,
                        directory = vim.fs.joinpath(notes_dir, "projects"),
                        title = project_note_title,
                        command_name = "ProjectNote",
                        window_config = function()
                            return note_window_config(project_note_title())
                        end,
                        post_open = configure_note_buffer,
                    },
                },
            })
        end,
    },
    {
        "MeanderingProgrammer/render-markdown.nvim",
        ft = { "markdown" },
        dependencies = {
            "nvim-treesitter/nvim-treesitter",
            "nvim-tree/nvim-web-devicons",
        },
        keys = {
            { "<leader>mr", "<cmd>RenderMarkdown toggle<CR>", desc = "Toggle Markdown Render" },
        },
        opts = {
            preset = "obsidian",
            render_modes = { "n", "c", "t" },
            file_types = { "markdown" },
            completions = {
                lsp = { enabled = true },
            },
        },
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
                    dashboard_cat_section,
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
                pattern = "SnacksDashboardOpened",
                callback = start_dashboard_cat_animation,
            })

            vim.api.nvim_create_autocmd({ "VimLeavePre", "VimSuspend" }, {
                callback = stop_dashboard_cat_animation,
            })

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
        "famiu/feline.nvim",
        dependencies = { "catppuccin/nvim", "nvim-tree/nvim-web-devicons" },
        config = function()
            require("feline").setup()
        end,
    },
    {
        "catppuccin/nvim",
        name = "catppuccin",
        lazy = false,
        priority = 1000,
        opts = {
            flavour = "mocha",
            auto_integrations = true,
        },
        config = function(_, opts)
            require("catppuccin").setup(opts)
            vim.cmd.colorscheme("catppuccin-mocha")
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
                "markdown_inline",
                "bash",
                "python",
                "html",
                "yaml",
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

            cmp.setup.filetype({ "sql", "mysql", "plsql", "sqlite" }, {
                sources = cmp.config.sources({
                    {
                        name = "vim-dadbod-completion",
                        group_index = 1,
                    },
                    {
                        name = "buffer",
                        group_index = 2,
                        keyword_length = 2,
                    },
                    {
                        name = "path",
                        group_index = 2,
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
            local debug_workbench = require("debug_workbench")
            dapui.setup(debug_workbench.dapui_config())
            debug_workbench.setup(dap)
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
            { "tpope/vim-dadbod",                     cmd = { "DB" }, ft = { "sql", "mysql", "plsql", "sqlite" }, lazy = true },
            { "kristijanhusak/vim-dadbod-completion", ft = { "sql", "mysql", "plsql", "sqlite" }, lazy = true },
        },
        cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection", "DBUIFindBuffer" },
        init = function()
            -- use nerd fonts for nice icons in DBUI
            vim.g.db_ui_use_nerd_fonts = 1
            vim.g.db_ui_save_location = vim.fn.stdpath("data") .. "/dadbod_ui"
            vim.g.dbs = vim.g.dbs or {}
            vim.g.vim_dadbod_completion_mark = "[DB]"
            vim.g.vim_dadbod_completion_lowercase_keywords = 1
            vim.g.vim_dadbod_completion_source_limits = {
                tables = 200,
                columns = 300,
            }
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

local function normalize_virtual_text_handler_opts(opts)
    if type(opts) ~= "table" then
        return nil
    end

    if type(opts.virtual_text) == "table" then
        return vim.deepcopy(opts)
    end

    if opts.virtual_text == true then
        local resolved = vim.deepcopy(opts)
        resolved.virtual_text = {}
        return resolved
    end

    if opts.virtual_text ~= nil then
        return nil
    end

    local config = vim.diagnostic.config()
    local resolved = type(config) == "table" and vim.deepcopy(config) or {}
    resolved.virtual_text = vim.deepcopy(opts)
    return resolved
end

local function resolve_virtual_text_opts(bufnr, opts)
    local resolved = normalize_virtual_text_handler_opts(opts)
    if resolved then
        virtual_text_handler_opts[bufnr] = resolved
        return resolved
    end

    local cached = virtual_text_handler_opts[bufnr]
    if type(cached) == "table" and type(cached.virtual_text) == "table" then
        return cached
    end

    resolved = normalize_virtual_text_handler_opts(vim.diagnostic.config())
    if resolved then
        virtual_text_handler_opts[bufnr] = resolved
        return resolved
    end

    return nil
end

local function refresh_virtual_text(bufnr, opts)
    local resolved_bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
    if not resolved_bufnr or not vim.api.nvim_buf_is_valid(resolved_bufnr) then
        return
    end

    original_virtual_text_handler.hide(deduped_virtual_text_namespace, resolved_bufnr)

    local handler_opts = resolve_virtual_text_opts(resolved_bufnr, opts)
    if not handler_opts then
        return
    end

    local get_opts = {}
    if handler_opts.virtual_text.severity then
        get_opts.severity = handler_opts.virtual_text.severity
    end

    -- Some servers publish identical messages for slightly different spans. Collapse those
    -- before rendering virtual text so the line only shows one inline diagnostic message.
    local diagnostics = dedupe_virtual_text_diagnostics(resolved_bufnr, get_visible_diagnostics(resolved_bufnr, get_opts))
    if diagnostics and not vim.tbl_isempty(diagnostics) then
        original_virtual_text_handler.show(
            deduped_virtual_text_namespace,
            resolved_bufnr,
            diagnostics,
            handler_opts
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

-- Do not let slow LSP `textDocument/willSave` requests block `:write`.
-- Diagnostics, completion, and normal LSP features remain enabled.
local function remove_lsp_willsave(bufnr)
    for _, autocmd in ipairs(vim.api.nvim_get_autocmds({ event = "BufWritePre", buffer = bufnr })) do
        if autocmd.group_name and autocmd.group_name:match("^nvim%.lsp%.b_") then
            pcall(vim.api.nvim_del_autocmd, autocmd.id)
        end
    end
end

vim.api.nvim_create_autocmd({ "BufEnter", "LspAttach" }, {
    callback = function(args)
        vim.defer_fn(function()
            if vim.api.nvim_buf_is_valid(args.buf) then
                remove_lsp_willsave(args.buf)
            end
        end, 100)
    end,
    desc = "Keep LSP willSave from blocking writes",
})

local enabled_lsps = { "lua_ls", "clangd", "pyright", "html", "lemminx" }
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


local tree_mode_file = vim.fn.stdpath("data") .. "/active-file-tree"

local function read_file_tree_mode()
    local mode = vim.fn.filereadable(tree_mode_file) == 1 and vim.fn.readfile(tree_mode_file)[1] or "mini.files"
    if mode == "neo-tree" then
        return mode
    end
    return "mini.files"
end

local function write_file_tree_mode(mode)
    vim.fn.mkdir(vim.fn.fnamemodify(tree_mode_file, ":h"), "p")
    vim.fn.writefile({ mode }, tree_mode_file)
end

local function close_mini_files()
    pcall(function()
        local mf = require("mini.files")
        if mf.get_explorer_state() ~= nil then
            mf.close()
        end
    end)
end

local function close_neo_tree()
    pcall(vim.cmd, "Neotree close")
end

local file_tree_root_markers = {
    ".git",
    "package.json",
    "Cargo.toml",
    "go.mod",
    "pyproject.toml",
    "CMakeLists.txt",
    "Makefile",
    "*.sln",
    "*.csproj",
    "*.xcodeproj",
    "*.xcworkspace",
    "Package.swift",
}

local function current_normal_file()
    local path = vim.api.nvim_buf_get_name(0)
    if path == "" or vim.bo[0].buftype ~= "" then
        return nil
    end
    return vim.fn.fnamemodify(path, ":p")
end

local function directory_for_file_tree_root()
    local file = current_normal_file()
    if file and vim.fn.filereadable(file) == 1 then
        return vim.fn.fnamemodify(file, ":p:h")
    end

    local cwd = vim.fn.getcwd()
    if cwd ~= "" then
        return vim.fn.fnamemodify(cwd, ":p")
    end

    return vim.loop.cwd() or nil
end

local function file_tree_project_root()
    local start = directory_for_file_tree_root()
    if not start or start == "" then
        return vim.fn.getcwd()
    end

    local root = vim.fs.root(start, file_tree_root_markers)
    if root and root ~= "" then
        return root
    end

    return start
end

local function toggle_mini_files()
    close_neo_tree()
    local mf = require("mini.files")
    if mf.get_explorer_state() ~= nil then
        mf.close()
    else
        mf.open(file_tree_project_root(), false)
    end
end

local function toggle_neo_tree()
    close_mini_files()
    pcall(function()
        require("lazy").load({ plugins = { "neo-tree.nvim" } })
    end)
    local file = current_normal_file()
    local ok = pcall(function()
        require("neo-tree.command").execute({
            action = "focus",
            toggle = true,
            source = "filesystem",
            position = "left",
            dir = file_tree_project_root(),
            reveal_file = file,
        })
    end)
    if not ok then
        vim.notify("neo-tree is not installed yet; run :Lazy sync, then use <leader>nT again", vim.log.levels.WARN)
    end
end

local function toggle_active_file_tree()
    if read_file_tree_mode() == "neo-tree" then
        toggle_neo_tree()
    else
        toggle_mini_files()
    end
end

vim.api.nvim_create_autocmd("User", {
    pattern = "PersistenceLoadPost",
    callback = function()
        close_mini_files()
        close_neo_tree()
    end,
})

local function switch_file_tree()
    local next_mode = read_file_tree_mode() == "neo-tree" and "mini.files" or "neo-tree"
    write_file_tree_mode(next_mode)
    close_mini_files()
    close_neo_tree()
    toggle_active_file_tree()
    vim.notify("File tree: " .. next_mode, vim.log.levels.INFO)
end

-- Buffer navigation keymaps
vim.keymap.set("n", "<leader>bn", "<cmd>bnext<CR>", { desc = "Next Buffer" })
vim.keymap.set("n", "<leader>bp", "<cmd>bprevious<CR>", { desc = "Prev Buffer" })
vim.keymap.set("n", "<leader>bo", "<cmd>enew<CR>", { desc = "New Buffer" })
vim.keymap.set("n", "<leader>bc", "<cmd>bdelete<CR>", { desc = "Close Buffer" })

-- Window management keymaps
-- These mappings mirror the defaults but with a leader prefix for convenience
local window_resize_mode_keys = { "h", "j", "k", "l", "<Esc>", "q" }
local window_resize_mode_buffers = {}

local function resize_current_window(direction, amount)
    amount = tonumber(amount) or 2
    local commands = {
        h = "vertical resize -" .. amount,
        l = "vertical resize +" .. amount,
        j = "resize -" .. amount,
        k = "resize +" .. amount,
    }
    if commands[direction] then
        vim.cmd(commands[direction])
    end
end

local function exit_window_resize_mode(buf)
    buf = buf or vim.api.nvim_get_current_buf()
    if not window_resize_mode_buffers[buf] then
        return
    end
    for _, lhs in ipairs(window_resize_mode_keys) do
        pcall(vim.keymap.del, "n", lhs, { buffer = buf })
    end
    window_resize_mode_buffers[buf] = nil
    vim.notify("Window resize mode off", vim.log.levels.INFO)
end

local function enter_window_resize_mode()
    local buf = vim.api.nvim_get_current_buf()
    if window_resize_mode_buffers[buf] then
        return
    end

    window_resize_mode_buffers[buf] = true
    local function map(lhs, rhs, desc)
        vim.keymap.set("n", lhs, rhs, { buffer = buf, nowait = true, silent = true, desc = desc })
    end

    map("h", function() resize_current_window("h", vim.v.count1) end, "Shrink window width")
    map("l", function() resize_current_window("l", vim.v.count1) end, "Grow window width")
    map("j", function() resize_current_window("j", vim.v.count1) end, "Shrink window height")
    map("k", function() resize_current_window("k", vim.v.count1) end, "Grow window height")
    map("<Esc>", function() exit_window_resize_mode(buf) end, "Exit window resize mode")
    map("q", function() exit_window_resize_mode(buf) end, "Exit window resize mode")

    vim.api.nvim_create_autocmd("BufWipeout", {
        buffer = buf,
        once = true,
        callback = function()
            window_resize_mode_buffers[buf] = nil
        end,
    })

    vim.notify("Window resize mode: h/l width, j/k height, counts work, Esc exits", vim.log.levels.INFO)
end

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
vim.keymap.set("n", "<leader>wm", enter_window_resize_mode, { desc = "Window Resize Mode" })
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
    { "<leader>nt", toggle_active_file_tree,                                  desc = "Toggle File Tree", icon = { icon = "󰉓 ", color = "cyan" } },
    { "<leader>nT", switch_file_tree,                                         desc = "Switch File Tree", icon = { icon = "󰉓 ", color = "cyan" } },
    -- { "<leader>nt", "<cmd>NvimTreeToggle<CR>",                                desc = "Toggle Nvim Tree" },
    -- { "<leader>nt", "<cmd>Neotree toggle filesystem left<CR>",                desc = "Toggle Neo-tree" },
    { "<leader>n",  group = "Notes/Notifications",                              icon = { icon = "󰎞 ", color = "blue" } },
    { "<leader>ng", desc = "Global Note" },
    { "<leader>np", desc = "Project Note" },
    { "<leader>nm", desc = "Note Move Mode" },
    { "<leader>t",  group = "Tasks/Terminal",                                   icon = { icon = " ", color = "yellow" } },
    { "<leader>u",  group = "UI/Toggles",                                       icon = { icon = " ", color = "yellow" } },
    -- Open
    { "<leader>o",  group = "Open",                                             icon = { icon = " ", color = "cyan" } },
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
    { "<leader>wm", enter_window_resize_mode,                                  desc = "Window Resize Mode" },
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
        function() dbui_open_sqlite({ fullscreen = true, buf = vim.api.nvim_get_current_buf() }) end,
        desc = "Open DBUI (Fullscreen)"
    },
    { "<leader>qc", "<cmd>DBUIToggle<CR>",    desc = "Toggle DBUI" },
    { "<leader>qr", "<cmd>DBUIRename<CR>",    desc = "Rename Connection" },
    { "<leader>qs", "<cmd>DBUISaveQuery<CR>", desc = "Save Query" },
    {
        "<leader>qf",
        function() dbui_open_sqlite({ buf = vim.api.nvim_get_current_buf() }) end,
        desc = "Open SQLite File"
    },
    -- Markdown
    { "<leader>m",  group = "Markdown",                                         icon = { icon = " ", color = "blue" } },
    { "<leader>mp", "<cmd>MarkdownPreviewToggle<CR>",                  desc = "MD Preview" },
    { "<leader>mr", desc = "Toggle Markdown Render" },
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
    { "<leader>dt", function() require("dap").terminate() end,         desc = "Terminate Debug" },
    { "<leader>du", function() require("debug_workbench").toggle_workbench() end, desc = "Debug Workbench" },
    { "<leader>dU", function() require("debug_workbench").close_workbench() end,  desc = "Close Debug Workbench" },
    { "<leader>dT", function() require("debug_workbench").toggle_terminal() end,  desc = "Debug Terminal" },
    {
        "<leader>dm",
        function() require("debug_workbench").terminal_resize_mode() end,
        desc = "Move/Resize Debug Terminal",
    },
    { "<leader>dr", function() require("debug_workbench").toggle_resource_panel() end, desc = "Debug Resources" },
    { "<leader>dl", function() require("debug_workbench").toggle_resource_log() end,   desc = "Log Debug Resources" },
    { "<leader>ds", function() require("debug_workbench").take_resource_snapshot() end, desc = "Debug Resource Snapshot" },
    { "<leader>dp", function() require("debug_workbench").prompt_resource_pid() end,    desc = "Set Debug Resource PID" },
    { "<leader>dH", function() require("debug_workbench").check_adapters() end,         desc = "Debug Adapter Health" },
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

-- Route SQLite files through DBUI before Neovim reads the binary database.
vim.api.nvim_create_autocmd("BufReadCmd", {
    pattern = { "*.sqlite", "*.db", "*.sqlite3", "*.db3" },
    callback = function(args)
        local file = args.file
        local buf = args.buf
        if vim.api.nvim_buf_is_valid(buf) then
            vim.bo[buf].buftype = "nofile"
            vim.bo[buf].bufhidden = "wipe"
            vim.bo[buf].swapfile = false
            vim.bo[buf].modifiable = true
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
                "SQLite database opened in DBUI:",
                vim.fn.fnamemodify(file, ":p"),
            })
            vim.bo[buf].modifiable = false
        end
        vim.schedule(function()
            dbui_open_sqlite({ buf = buf, file = file })
        end)
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
    require("debug_workbench").setup_adapters(dap_mod)
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

vim.keymap.set("n", "<leader>nt", toggle_active_file_tree, { desc = "Toggle File Tree" })
vim.keymap.set("n", "<leader>nT", switch_file_tree, { desc = "Switch File Tree" })

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
