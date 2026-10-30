vim.opt.rtp:prepend(vim.fn.getcwd() .. "/nvim")
local has, executable, system = vim.fn.has, vim.fn.executable, vim.system
local developer = vim.env.DEVELOPER_DIR
local selected, installed, calls = "/Library/Developer/CommandLineTools", {}, 0
vim.env.DEVELOPER_DIR = nil
vim.fn.has = function() return 1 end
vim.fn.executable = function(path) return installed[path] and 1 or 0 end
vim.system = function()
  calls = calls + 1
  return { wait = function() return { code = 0, stdout = selected .. "\n" } end }
end
local toolchain = require("swift_toolchain")
assert(toolchain.environment() == nil, "No Xcode must preserve the selected tools")
local beta = "/Applications/Xcode-beta.app/Contents/Developer"
local stable = "/Applications/Xcode.app/Contents/Developer"
installed[beta .. "/usr/bin/xcodebuild"] = true
assert(toolchain.environment().DEVELOPER_DIR == beta)
installed[stable .. "/usr/bin/xcodebuild"] = true
assert(toolchain.environment().DEVELOPER_DIR == stable, "Prefer stable Xcode")
selected = "/custom/Xcode.app/Contents/Developer"
assert(toolchain.environment() == nil, "Preserve selected full Xcode")
vim.env.DEVELOPER_DIR = "/custom/toolchain"
local before = calls
assert(toolchain.environment() == nil and calls == before, "Preserve explicit environment")
vim.env.DEVELOPER_DIR = nil
vim.fn.has = function() return 0 end
assert(toolchain.environment() == nil and calls == before, "Linux must not call xcode-select")
vim.fn.has = function() return 1 end
vim.system = function() error("ENOENT") end
assert(toolchain.environment() == nil, "Failed spawn must not abort setup")
vim.system = function() return { wait = function() return { code = 124 } end } end
assert(toolchain.environment() == nil, "Timed-out lookup must preserve the environment")
vim.fn.has, vim.fn.executable, vim.system = has, executable, system
vim.env.DEVELOPER_DIR = developer
print("Swift toolchain selection: passed")
vim.cmd("qa!")
