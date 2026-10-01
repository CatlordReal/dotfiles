local M = {}
local pending_shows = {}

-- Display overrides pass explicit diagnostics to Neovim and bypass its cached
-- diagnostic clamp. Match diagnostic.lua's display clamp without moving cached
-- positions used by quickfix and other consumers.
function M.clamp(bufnr, diagnostics)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return {}
    end
    if not diagnostics or not vim.api.nvim_buf_is_loaded(bufnr) then
        return diagnostics
    end

    local line_count = vim.api.nvim_buf_line_count(bufnr) - 1
    local bounded = {}
    for _, diagnostic in ipairs(diagnostics) do
        if diagnostic.lnum > line_count
            or diagnostic.end_lnum > line_count
            or diagnostic.lnum < 0
            or diagnostic.end_lnum < 0
            or diagnostic.col < 0
            or diagnostic.end_col < 0
        then
            diagnostic = vim.deepcopy(diagnostic, true)
            diagnostic.lnum = math.max(math.min(diagnostic.lnum, line_count), 0)
            diagnostic.end_lnum = math.max(math.min(diagnostic.end_lnum, line_count), 0)
            diagnostic.col = math.max(diagnostic.col, 0)
            diagnostic.end_col = math.max(diagnostic.end_col, 0)
        end
        bounded[#bounded + 1] = diagnostic
    end
    return bounded
end

local function cancel_buffer_show(bufnr, namespace)
    local pending = pending_shows[bufnr]
    if not pending then return end

    local function remove_one(key)
        local request = pending.requests[key]
        if not request then return end
        pending.requests[key] = nil
        if request.autocmd_id then pcall(vim.api.nvim_del_autocmd, request.autocmd_id) end
    end

    if namespace ~= nil then
        remove_one(namespace)
    else
        for key in pairs(pending.requests) do remove_one(key) end
    end

    if next(pending.requests) == nil then
        pending_shows[bufnr] = nil
        if pending.wipe_id then pcall(vim.api.nvim_del_autocmd, pending.wipe_id) end
    end
end

function M.cancel_show(namespace, bufnr)
    if bufnr ~= nil then
        cancel_buffer_show(bufnr, namespace)
    else
        local buffers = {}
        for pending_bufnr in pairs(pending_shows) do
            buffers[#buffers + 1] = pending_bufnr
        end
        for _, pending_bufnr in ipairs(buffers) do
            cancel_buffer_show(pending_bufnr, namespace)
        end
    end
end

-- An unloaded buffer has no line count to clamp against. Neovim's underline
-- handler captures unbounded coordinates before BufRead. Keep only latest show
-- request, then render synchronously on BufReadPost with real buffer content.
function M.defer_show(namespace, bufnr, diagnostics, opts)
    if not vim.api.nvim_buf_is_valid(bufnr) then return end

    local pending = pending_shows[bufnr]
    if not pending then
        pending = { requests = {} }
        pending_shows[bufnr] = pending
        pending.wipe_id = vim.api.nvim_create_autocmd("BufWipeout", {
            buffer = bufnr,
            once = true,
            callback = function()
                pending.wipe_id = nil
                M.cancel_show(nil, bufnr)
            end,
        })
    end

    local request = pending.requests[namespace]
    if request then
        request.diagnostics = diagnostics
        request.opts = opts
        return
    end

    request = { diagnostics = diagnostics, opts = opts }
    pending.requests[namespace] = request
    request.autocmd_id = vim.api.nvim_create_autocmd("BufReadPost", {
        buffer = bufnr,
        once = true,
        callback = function()
            if pending_shows[bufnr] ~= pending or pending.requests[namespace] ~= request then
                return
            end
            local latest_diagnostics, latest_opts = request.diagnostics, request.opts
            M.cancel_show(namespace, bufnr)
            if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
                vim.diagnostic.show(namespace, bufnr, latest_diagnostics, latest_opts)
            end
        end,
    })
end

return M
