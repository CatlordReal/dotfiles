local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

sbar.add("event", "shelf_changed")

local popup_width = 280
local max_items = 5

local shelf = sbar.add("item", "shelf", {
  position = "center",
  update_freq = 15,
  icon = {
    string = icons.folder,
    color = colors.blue,
    padding_left = 8,
    padding_right = 4,
  },
  label = {
    string = "Shelf",
    color = colors.white,
    font = { style = settings.font.style_map["Bold"], size = 11.0 },
    padding_left = 0,
    padding_right = 8,
  },
  background = {
    color = colors.with_alpha(colors.bg1, 0.72),
    border_color = colors.bg2,
    border_width = 1,
  },
  popup = { align = "center" },
})

local hint = sbar.add("item", "shelf.hint", {
  position = "popup." .. shelf.name,
  width = popup_width,
  align = "center",
  icon = { string = icons.folder, width = 28, align = "left", padding_left = 8, color = colors.blue },
  label = {
    string = "Click to open shelf folder",
    align = "left",
    width = popup_width - 46,
    padding_left = 0,
    padding_right = 8,
    color = colors.white,
  },
})

local rows = {}
for index = 1, max_items do
  rows[index] = sbar.add("item", "shelf.item." .. index, {
    position = "popup." .. shelf.name,
    drawing = false,
    width = popup_width,
    align = "center",
    icon = { string = "􀈷", width = 28, align = "left", padding_left = 8, color = colors.grey },
    label = {
      string = "",
      align = "left",
      width = popup_width - 46,
      max_chars = 28,
      padding_left = 0,
      padding_right = 8,
      color = colors.grey,
    },
  })
end

local function shell_quote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function parse_shelf(output)
  local lines = {}
  for line in (output or ""):gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end

  local count = tonumber(lines[1] or "0") or 0
  shelf:set({
    label = count > 0 and ("Shelf " .. count) or "Shelf",
    icon = { color = count > 0 and colors.magenta or colors.blue },
  })
  hint:set({ label = count > 0 and "Open shelf folder" or "Open shelf folder to add files" })

  for index = 1, max_items do
    local line = lines[index + 1]
    if line then
      local name, path = line:match("^([^|]*)|(.*)$")
      rows[index]:set({
        drawing = true,
        label = name or line,
        click_script = "$HOME/.config/scripts/shelf.sh reveal " .. shell_quote(path or ""),
      })
    else
      rows[index]:set({ drawing = false })
    end
  end
end

local function update_shelf()
  sbar.exec("$HOME/.config/scripts/shelf.sh list", parse_shelf)
end

local function set_popup(drawing)
  shelf:set({ popup = { drawing = drawing } })
  sbar.animate("tanh", 16, function()
    shelf:set({ background = { color = drawing and colors.bg2 or colors.with_alpha(colors.bg1, 0.72) } })
  end)
end

shelf:subscribe({ "forced", "routine", "system_woke", "shelf_changed" }, update_shelf)

shelf:subscribe("mouse.clicked", function(env)
  if env.BUTTON == "right" then
    update_shelf()
    set_popup(shelf:query().popup.drawing == "off")
  else
    sbar.exec("$HOME/.config/scripts/shelf.sh open")
  end
end)

shelf:subscribe("mouse.entered", function()
  update_shelf()
  set_popup(true)
end)

shelf:subscribe("mouse.exited.global", function()
  set_popup(false)
end)

update_shelf()
