local script = debug.getinfo(1, "S").source:sub(2)
local root = vim.fn.fnamemodify(script, ":h:h")
vim.opt.rtp:prepend(root .. "/nvim")
local init = table.concat(vim.fn.readfile(root .. "/nvim/init.lua"), "\n")
local lock = table.concat(vim.fn.readfile(root .. "/nvim/lazy-lock.json"), "\n")

assert(not init:find('require("nvim%-treesitter%.configs")'), "legacy nvim-treesitter.configs API remains")
assert(init:find('"nvim%-treesitter/nvim%-treesitter"'))
assert(init:find('branch = "main"'))
assert(init:find('lazy = false'))
assert(init:find('vim%.fn%.has%("nvim%-0%.12"%)'))
assert(init:find('require%("dotfiles_treesitter"%)%.setup'))
assert(not init:find('foldexpr = .-vim%.treesitter%.foldexpr'), "nvim-ufo folding must remain authoritative")
assert(not init:find('indentexpr = .-nvim%-treesitter'), "experimental treesitter indentation was enabled")
assert(lock:find('"nvim%-treesitter": { "branch": "main", "commit": "f603a2f4da48728f80257fb5fbb90145fd1dc173" }'))

local runner = require("dotfiles_treesitter")
local original_get_lang = vim.treesitter.language.get_lang
local original_start = vim.treesitter.start
local seen = {}
vim.treesitter.language.get_lang = function(filetype)
  return ({ cpp = "cpp", cs = "c_sharp", sh = "bash" })[filetype] or filetype
end
vim.treesitter.start = function(buffer, language)
  table.insert(seen, { buffer = buffer, language = language })
end
local function buffer(filetype)
  local value = vim.api.nvim_create_buf(false, true)
  vim.bo[value].filetype = filetype
  return value
end
for filetype, language in pairs({ cpp = "cpp", cs = "c_sharp", sh = "bash" }) do
  local value = buffer(filetype)
  assert(runner.start_buffer(value))
  assert(seen[#seen].buffer == value and seen[#seen].language == language)
end
local retry = buffer("cpp")
local callback
runner.setup({
  setup = function() end,
  install = function()
    return { await = function(_, fn) callback = fn end }
  end,
})
local before = #seen
callback(nil)
assert(vim.wait(1000, function() return #seen > before end, 10), "async parser install did not retry open buffers")
assert(vim.tbl_contains(vim.tbl_map(function(value) return value.buffer end, seen), retry))
vim.treesitter.language.get_lang = original_get_lang
vim.treesitter.start = original_start

print("treesitter migration: ok")
