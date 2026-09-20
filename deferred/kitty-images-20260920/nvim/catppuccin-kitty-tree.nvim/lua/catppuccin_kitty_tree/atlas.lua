local M = {}

local flavours = {
  latte = true,
  frappe = true,
  macchiato = true,
  mocha = true,
}

local function lowercase(value)
  return type(value) == "string" and value:lower() or nil
end

local function basename(entry)
  if entry.name and entry.name ~= "" then
    return entry.name
  end
  return entry.path and vim.fn.fnamemodify(entry.path, ":t") or nil
end

local Atlas = {}
Atlas.__index = Atlas

function Atlas:_theme(flavour)
  flavour = lowercase(flavour)
  if not flavours[flavour] then
    return nil
  end
  if self.themes[flavour] then
    return self.themes[flavour]
  end

  local theme_path = self.root .. "/" .. flavour .. "/theme.json"
  local ok, lines = pcall(vim.fn.readfile, theme_path)
  if not ok then
    return nil
  end
  local decoded_ok, theme = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not decoded_ok or type(theme) ~= "table" then
    return nil
  end

  local extensions = {}
  for extension, _ in pairs(theme.fileExtensions or {}) do
    extensions[#extensions + 1] = extension:lower()
  end
  table.sort(extensions, function(a, b)
    if #a == #b then
      return a < b
    end
    return #a > #b
  end)

  local loaded = {
    data = theme,
    dir = vim.fn.fnamemodify(theme_path, ":h"),
    extensions = extensions,
  }
  self.themes[flavour] = loaded
  return loaded
end

local function icon_path(theme, icon_id)
  local definition = theme.data.iconDefinitions and theme.data.iconDefinitions[icon_id]
  local relative_path = definition and (definition.iconPath or definition.icon)
  if type(relative_path) ~= "string" or relative_path == "" then
    return nil, nil
  end
  return vim.fs.normalize(theme.dir .. "/" .. relative_path:gsub("^%./", "")), icon_id
end

local function file_icon_id(theme, entry, name)
  local lower_name = lowercase(name)
  local files = theme.data.fileNames or {}
  local icon_id = files[lower_name]
  if icon_id then
    return icon_id
  end

  for _, extension in ipairs(theme.extensions) do
    if #lower_name > #extension and lower_name:sub(-#extension - 1) == "." .. extension then
      return (theme.data.fileExtensions or {})[extension]
    end
  end

  local language = lowercase(entry.language)
  if language then
    icon_id = (theme.data.languageIds or {})[language]
    if icon_id then
      return icon_id
    end
  end
  return theme.data.file
end

local function directory_icon_id(theme, entry, name)
  if entry.root then
    return entry.expanded and theme.data.rootFolderExpanded or theme.data.rootFolder
  end

  local lower_name = lowercase(name)
  local named = entry.expanded and theme.data.folderNamesExpanded or theme.data.folderNames
  local icon_id = (named or {})[lower_name]
  if icon_id then
    return icon_id
  end
  return entry.expanded and theme.data.folderExpanded or theme.data.folder
end

--- Resolve one VS Code icon-theme entry to its SVG asset and icon definition ID.
---@param entry table { name?: string, path?: string, kind?: 'file'|'directory', expanded?: boolean, root?: boolean, language?: string }
---@param flavour string
---@return string? absolute_path
---@return string? icon_id
function Atlas:resolve(entry, flavour)
  if type(entry) ~= "table" then
    return nil, nil
  end
  local theme = self:_theme(flavour)
  local name = basename(entry)
  if not theme or not name or name == "" then
    return nil, nil
  end

  local kind = entry.kind or "file"
  local icon_id
  if kind == "directory" then
    icon_id = directory_icon_id(theme, entry, name)
  elseif kind == "file" then
    icon_id = file_icon_id(theme, entry, name)
  else
    return nil, nil
  end
  return icon_path(theme, icon_id)
end

function M.new(root)
  assert(type(root) == "string" and root ~= "", "atlas.new(root) requires an icon-theme root")
  return setmetatable({ root = vim.fs.normalize(root), themes = {} }, Atlas)
end

return M
