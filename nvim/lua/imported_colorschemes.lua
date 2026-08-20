local M = {}

local function notify(message)
    vim.notify("Imported colourschemes: " .. message, vim.log.levels.WARN)
end

local function is_absolute(path)
    return path:sub(1, 1) == "/"
end

local function runtime_path_contains(path)
    for _, runtime_path in ipairs(vim.api.nvim_list_runtime_paths()) do
        if runtime_path == path then
            return true
        end
    end
    return false
end

local function scheme_files(root)
    local files = {}
    for _, pattern in ipairs({ "colors/*.vim", "colors/*.lua" }) do
        vim.list_extend(files, vim.fn.globpath(root, pattern, false, true))
    end
    table.sort(files)
    return files
end

---Load absolute colourscheme runtime roots configured in imported-colorschemes.txt.
---Each returned item preserves its colourscheme filename's case for :colorscheme.
function M.load()
    local config_file = vim.fn.stdpath("config") .. "/imported-colorschemes.txt"
    local ok, lines = pcall(vim.fn.readfile, config_file)
    if not ok then
        return {}
    end

    local roots = {}
    local seen_roots = {}
    for line_number, line in ipairs(lines) do
        local configured_root = vim.trim(line)
        if configured_root ~= "" and not vim.startswith(configured_root, "#") then
            if not is_absolute(configured_root) then
                notify(("ignoring line %d; root must be absolute: %s"):format(line_number, configured_root))
            else
                local root = vim.uv.fs_realpath(configured_root)
                if not root or vim.fn.isdirectory(root) ~= 1 then
                    notify(("ignoring line %d; runtime root not found: %s"):format(line_number, configured_root))
                elseif not seen_roots[root] then
                    seen_roots[root] = true
                    table.insert(roots, root)
                    if not runtime_path_contains(root) then
                        vim.opt.runtimepath:append(root)
                    end
                end
            end
        end
    end

    local schemes = {}
    local seen_scheme_names = {}
    for _, root in ipairs(roots) do
        for _, file in ipairs(scheme_files(root)) do
            local name = vim.fn.fnamemodify(file, ":t:r")
            local folded_name = name:lower()
            if not seen_scheme_names[folded_name] then
                seen_scheme_names[folded_name] = true
                table.insert(schemes, {
                    id = "imported:" .. vim.fn.sha256(root):sub(1, 12) .. ":" .. name,
                    name = name,
                    root = root,
                })
            end
        end
    end

    return schemes
end

return M
