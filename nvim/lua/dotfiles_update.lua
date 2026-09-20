local M = {}

local function script_path()
    return vim.env.DOTFILES_UPDATE_SCRIPT or (vim.fn.stdpath("config") .. "/scripts/update-dotfiles.py")
end

local function run(arguments, callback)
    vim.system(vim.list_extend({ "python3", script_path() }, arguments), { text = true }, function(result)
        vim.schedule(function() callback(result) end)
    end)
end

local function show(title, text)
    vim.cmd("botright new")
    local buffer = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buffer, 0, -1, false, vim.list_extend({ title, "" }, vim.split(text or "", "\n", { plain = true })))
    vim.bo[buffer].buftype, vim.bo[buffer].bufhidden, vim.bo[buffer].modifiable = "nofile", "wipe", false
end

local function diagnostic(result)
    local stdout = result.stdout or ""
    local stderr = result.stderr or ""
    if stderr ~= "" then stdout = stdout .. (stdout == "" and "" or "\n") .. stderr end
    if result.signal and result.signal ~= 0 then stdout = stdout .. "\nprocess signal: " .. result.signal end
    return stdout == "" and "dotfiles updater produced no output" or stdout
end

local function preview(include_root_shell, callback)
    local args = { "--refresh", "--json" }
    if include_root_shell then table.insert(args, "--include-root-shell") end
    run(args, function(result)
        local output = diagnostic(result)
        if result.code ~= 0 then
            show("Dotfiles update failed", output)
            vim.notify("Dotfiles update preflight failed", vim.log.levels.ERROR)
            return
        end
        local ok, parsed = pcall(vim.json.decode, output)
        if not ok or type(parsed.plan) ~= "table" then
            show("Dotfiles update failed", output)
            return
        end
        callback(parsed, output)
    end)
end

function M.check()
    preview(false, function(_, output) show("Dotfiles update preview", output) end)
end

function M.update(include_root_shell)
    preview(include_root_shell == true, function(plan, output)
        local targets = {}
        for _, item in ipairs(plan.plan) do table.insert(targets, item.action .. ": " .. item.target) end
        if #targets == 0 then
            show("Dotfiles update preview", output)
            vim.notify("No changed installed dotfiles", vim.log.levels.INFO)
            return
        end
        local message = table.concat(targets, "\n") .. "\n\nBackup scope: " .. #plan.backup_scope .. " files. Apply exact revision " .. plan.revision:sub(1, 12) .. "?"
        if vim.fn.confirm(message, "&Apply\n&Cancel", 2) ~= 1 then return end
        local args = { "--apply", "--yes", "--json", "--revision", plan.revision, "--plan-id", plan.plan_id }
        if include_root_shell then table.insert(args, "--include-root-shell") end
        run(args, function(result)
            show("Dotfiles update result", diagnostic(result))
            if result.code == 0 then
                vim.notify("Dotfiles copied. Restart Neovim to load config; plugin updates were not run.", vim.log.levels.INFO)
            else
                vim.notify("Dotfiles update failed", vim.log.levels.ERROR)
            end
        end)
    end)
end

function M.setup()
    vim.api.nvim_create_user_command("DotfilesUpdateCheck", M.check, {})
    vim.api.nvim_create_user_command("DotfilesUpdate", function() M.update(false) end, {})
    vim.api.nvim_create_user_command("DotfilesUpdateAll", function() M.update(true) end, {})
end

return M
