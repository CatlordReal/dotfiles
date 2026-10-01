package.path = vim.fn.getcwd() .. "/nvim/lua/?.lua;" .. package.path
local bounds = require("dotfiles_diagnostic_bounds")
local buffer = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "short" })
local namespace = vim.api.nvim_create_namespace("diagnostic-bounds-test")
local original = { bufnr = buffer, namespace = namespace, lnum = 50, end_lnum = 55, col = 0, end_col = 1,
    severity = vim.diagnostic.severity.ERROR, message = "stale server position" }
local displayed = bounds.clamp(buffer, { original })
assert(original.lnum == 50 and original.end_lnum == 55, "cached locations must remain intact")
vim.diagnostic.show(namespace, buffer, displayed, { virtual_text = true, underline = true })
assert(#vim.api.nvim_buf_get_extmarks(buffer, -1, 0, -1, {}) > 0, "diagnostic must still render")
vim.api.nvim_buf_delete(buffer, { force = true })
assert(#bounds.clamp(buffer, { original }) == 0, "deleted buffers must be ignored")
print("diagnostic bounds: ok")
