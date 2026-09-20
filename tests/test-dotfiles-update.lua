local root = vim.fn.getcwd()
vim.opt.rtp:prepend(root .. "/nvim")
package.path = root .. "/nvim/lua/?.lua;" .. package.path

local helper = vim.fn.tempname()
vim.fn.writefile({
    "#!/usr/bin/env python3",
    "import sys",
    "if '--fail' in sys.argv:",
    "    print('fake stderr', file=sys.stderr); raise SystemExit(1)",
    "print('{\"revision\":\"abc\",\"plan_id\":\"id\",\"plan\":[],\"backup_scope\":[]}')",
}, helper)
vim.fn.system({ "chmod", "+x", helper })
vim.env.DOTFILES_UPDATE_SCRIPT = helper

local update = require("dotfiles_update")
update.check()
update.check()
assert(vim.wait(3000, function()
    local count = 0
    for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
        local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
        if lines[1] == "Dotfiles update preview" then count = count + 1 end
    end
    return count == 2
end), "two successful async previews did not render")

vim.fn.writefile({ "#!/usr/bin/env python3", "import sys", "print('fake stderr', file=sys.stderr); raise SystemExit(1)" }, helper)
update.check()
assert(vim.wait(3000, function()
    for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
        local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
        if lines[1] == "Dotfiles update failed" and table.concat(lines, "\n"):find("fake stderr", 1, true) then return true end
    end
    return false
end), "failed async preview did not render stderr")

vim.fn.delete(helper)
