local function assert_line(expected)
    assert(vim.api.nvim_get_current_line() == expected, vim.api.nvim_get_current_line())
end

vim.cmd("enew!")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "left {} middle {} right" })
vim.cmd("%s/{}//g")
assert_line("left  middle  right")

vim.cmd("enew!")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "a aa aaa" })
vim.cmd("%s/a\\{2}/X/g")
assert_line("a X Xa")

vim.cmd("enew!")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "token token" })
vim.cmd("%s/token/{value}/g")
assert_line("{value} {value}")

print("regex substitute: ok")
