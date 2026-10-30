-- Uses the installed nvim-lspconfig, or the exact locked checkout supplied by CI.
local root = vim.fn.getcwd()
vim.opt.rtp:prepend(root .. "/nvim")
vim.opt.rtp:prepend(vim.env.NVIM_LSPCONFIG_RTP or (vim.fn.stdpath("data") .. "/lazy/nvim-lspconfig"))
local source = table.concat(vim.fn.readfile(root .. "/nvim/init.lua"), "\n")
local block = assert(source:match('(vim%.lsp%.config%["sourcekit"%] = {.-\n})'))
assert(loadstring("local cmp_caps = {}; " .. block))()
local config = vim.lsp.config.sourcekit
assert(vim.tbl_contains(config.filetypes, "swift"), "Swift filetype missing")

local fixture = vim.fn.tempname() .. "-swift"
vim.fn.mkdir(fixture .. "/Sources/Probe", "p")
fixture = assert(vim.uv.fs_realpath(fixture))
vim.fn.writefile({ '// swift-tools-version: 6.0', 'import PackageDescription',
  'let package = Package(name: "Probe", targets: [.executableTarget(name: "Probe")])' }, fixture .. "/Package.swift")
vim.fn.writefile({ 'print("Swift LSP probe")' }, fixture .. "/Sources/Probe/main.swift")
vim.cmd.edit(fixture .. "/Sources/Probe/main.swift")
local buffer = vim.api.nvim_get_current_buf()
local resolved
config.root_dir(buffer, function(dir) resolved = dir end)
assert(resolved == fixture, "SourceKit root callback did not resolve the Swift package: " .. tostring(resolved))

-- BSP build servers must take precedence over an enclosing Swift package.
vim.fn.writefile({ "{}" }, fixture .. "/Sources/buildServer.json")
config.root_dir(buffer, function(dir) resolved = dir end)
assert(resolved == fixture .. "/Sources", "BSP root was not preferred")
vim.fn.delete(fixture .. "/Sources/buildServer.json")

if vim.env.TEST_SOURCEKIT_ATTACH == "1" then
  vim.lsp.enable("sourcekit")
  vim.bo[buffer].filetype = "swift"
  local client
  assert(vim.wait(20000, function()
    client = vim.lsp.get_clients({ name = "sourcekit", bufnr = buffer })[1]
    return client and client.initialized
  end, 50), "SourceKit did not initialize and attach to the Swift buffer")
  assert(client.config.root_dir == fixture, "Attached to the wrong package")
  local response, err = client:request_sync("textDocument/hover", {
    textDocument = { uri = vim.uri_from_bufnr(buffer) }, position = { line = 0, character = 2 },
  }, 10000, buffer)
  assert(response and not response.err, vim.inspect(err or response))
  client:stop(true)
  print("SourceKit initialized, attached, and answered a hover request")
end
vim.fn.delete(fixture, "rf")
print("Swift LSP root regression: passed")
vim.cmd("qa!")
