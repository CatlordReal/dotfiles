local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
vim.opt.rtp:prepend(root .. "/nvim")
local test_state = vim.fn.tempname()
vim.env.XDG_STATE_HOME = test_state
local rotation = require("theme_rotation")
local checks = {
    { 0, 0, "mocha" }, { 6, 59, "mocha" }, { 7, 0, "latte" },
    { 15, 59, "latte" }, { 16, 0, "frappe" }, { 18, 59, "frappe" },
    { 19, 0, "macchiato" }, { 21, 59, "macchiato" }, { 22, 0, "mocha" }, { 23, 59, "mocha" },
}
for _, check in ipairs(checks) do
    assert(rotation.theme_at(check[1], check[2]) == "catppuccin-" .. check[3])
end
assert(not rotation.validate({ latte = "24:00", frappe = "16:00", macchiato = "19:00", mocha = "22:00" }))
assert(not rotation.validate({ latte = "07:00", frappe = "07:00", macchiato = "19:00", mocha = "22:00" }))
assert(not rotation.validate({ latte = "07:60", frappe = "16:00", macchiato = "19:00", mocha = "22:00" }))
local calls = 0
rotation.setup(function(theme, opts)
    assert(opts.rotation and opts.persist == false)
    calls = calls + 1
    vim.g.color_theme = theme
end)
rotation.start()
assert(calls == 1 and rotation.enabled())
rotation.tick()
assert(calls == 1, "Unchanged theme should not reload")
vim.g.color_theme = "stale"
vim.api.nvim_exec_autocmds("FocusGained", {})
assert(calls == 2, "Resume/focus should catch up")
rotation.stop()
rotation.tick(true)
assert(calls == 2 and not rotation.enabled())
package.loaded.theme_rotation = nil
assert(not require("theme_rotation").enabled(), "Manual stop should persist")
vim.fn.delete(test_state, "rf")
print("PASS: rotation boundaries, validation, focus, unchanged tick, stop persistence")
vim.cmd("qa!")
