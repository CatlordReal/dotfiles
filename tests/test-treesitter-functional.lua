local plugin = assert(vim.env.NVIM_TREESITTER_RTP, "set NVIM_TREESITTER_RTP to the installed nvim-treesitter main directory")
local script = debug.getinfo(1, "S").source:sub(2)
local root = vim.fn.fnamemodify(script, ":h:h")
vim.opt.rtp:prepend(plugin)
vim.opt.rtp:prepend(root .. "/nvim")
vim.cmd("runtime plugin/filetypes.lua")

local runner = require("dotfiles_treesitter")
for _, fixture in ipairs({
  { filetype = "cpp", language = "cpp", lines = { "int main() { return 0; }" } },
  { filetype = "cs", language = "c_sharp", lines = { "class Program { static void Main() {} }" } },
  { filetype = "sh", language = "bash", lines = { "#!/bin/sh", "echo ok" } },
}) do
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, fixture.lines)
  vim.bo[buffer].filetype = fixture.filetype
  assert(runner.start_buffer(buffer), fixture.filetype .. " failed to start")
  local ok, parser = pcall(vim.treesitter.get_parser, buffer, fixture.language)
  assert(ok and parser:lang() == fixture.language, fixture.filetype .. " parser unavailable or wrong language")
end

print("treesitter functional: ok")
