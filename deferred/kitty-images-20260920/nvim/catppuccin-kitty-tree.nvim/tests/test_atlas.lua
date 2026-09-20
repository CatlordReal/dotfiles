local source = debug.getinfo(1, "S").source:sub(2)
local plugin_root = vim.fn.fnamemodify(source, ":h:h")
local assets = vim.fn.stdpath("config") .. "/icons/catppuccin/vscode-icons/dist"

package.path = plugin_root .. "/lua/?.lua;" .. plugin_root .. "/lua/?/init.lua;" .. package.path
local atlas = require("catppuccin_kitty_tree.atlas").new(assets)

local function expect(entry, flavour, expected_id)
  local path, icon_id = atlas:resolve(entry, flavour)
  assert(icon_id == expected_id, vim.inspect({ entry = entry, flavour = flavour, expected = expected_id, actual = icon_id }))
  assert(type(path) == "string" and path:match("^/") and path:match("%.svg$"), tostring(path))
  assert(vim.fn.filereadable(path) == 1, path)
end

for _, flavour in ipairs({ "latte", "frappe", "macchiato", "mocha" }) do
  expect({ name = "index.js" }, flavour, "javascript")
  expect({ name = "widget.spec.ts" }, flavour, "typescript-test")
  expect({ name = "package.json" }, flavour, "package-json")
  expect({ name = "untitled", language = "typescript" }, flavour, "typescript")
  expect({ name = "src", kind = "directory" }, flavour, "folder_src")
  expect({ name = "src", kind = "directory", expanded = true }, flavour, "folder_src_open")
  expect({ name = "workspace", kind = "directory", root = true }, flavour, "_root")
  expect({ name = "workspace", kind = "directory", root = true, expanded = true }, flavour, "_root_open")
  expect({ name = "unknown-file" }, flavour, "_file")
  expect({ name = "unknown-folder", kind = "directory" }, flavour, "_folder")
  expect({ name = "unknown-folder", kind = "directory", expanded = true }, flavour, "_folder_open")
end

print("ATLAS_PASS")
