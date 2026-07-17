local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

sbar.add("event", "appearance_status_changed")

local control = sbar.add("item", "appearance_control", {
  position = "right",
  update_freq = 60,
  click_script = "/Users/kianconti/.config/scripts/appearance-click.sh",
  icon = {
    string = icons.gear,
    color = colors.magenta,
    padding_left = 9,
    padding_right = 9,
  },
  label = { drawing = false },
  background = { color = colors.bg1 },
})

sbar.add("item", "appearance_padding", {
  position = "right",
  width = settings.group_paddings,
})

local function parse_status(output)
  local status = {}
  for line in (output or ""):gmatch("[^\r\n]+") do
    local key, value = line:match("^([%w_]+)=(.*)$")
    if key then status[key] = value end
  end
  return status
end

local function update_status()
  sbar.exec("$HOME/.config/scripts/appearance-control.sh status", function(output)
    local status = parse_status(output)
    local theme = status.theme or "mocha"
    local session_on = status.session == "on"

    control:set({
      icon = {
        color = theme == "latte" and colors.yellow or colors.magenta,
      },
      background = {
        color = session_on and colors.bg1 or colors.with_alpha(colors.bg1, 0.45),
      },
    })
  end)
end

control:subscribe({ "forced", "routine", "system_woke", "appearance_status_changed" }, update_status)

control:subscribe("mouse.entered", function()
  sbar.animate("tanh", 14, function()
    control:set({ background = { color = colors.bg2 } })
  end)
end)

control:subscribe("mouse.exited", function()
  sbar.animate("tanh", 14, function()
    control:set({ background = { color = colors.bg1 } })
  end)
end)

update_status()
