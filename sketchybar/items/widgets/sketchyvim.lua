local colors = require("colors")
local settings = require("settings")

sbar.add("event", "sketchyvim_status_changed")
sbar.add("event", "sketchyvim_mode_changed")

local svim = sbar.add("item", "widgets.svim", {
  position = "right",
  icon = {
    string = "",
    color = colors.grey,
    font = {
      style = settings.font.style_map["Bold"],
      size = 14.0,
    },
  },
  label = {
    string = "off",
    color = colors.grey,
    font = {
      family = settings.font.numbers,
      style = settings.font.style_map["Bold"],
      size = 10.0,
    },
  },
  update_freq = 30,
})

sbar.add("bracket", "widgets.svim.bracket", { svim.name }, {
  background = { color = colors.bg1 }
})

sbar.add("item", "widgets.svim.padding", {
  position = "right",
  width = settings.group_paddings
})

local function update_status()
  sbar.exec("$HOME/.config/scripts/sketchyvim-toggle.sh status", function(result)
    local on = (result or ""):find("on") ~= nil
    svim:set({
      icon = { color = on and colors.green or colors.grey },
      label = { string = on and "svim" or "off", color = on and colors.white or colors.grey },
    })
  end)
end

svim:subscribe({ "routine", "sketchyvim_status_changed", "system_woke" }, update_status)

svim:subscribe("sketchyvim_mode_changed", function(env)
  local mode = env.MODE or ""
  if mode == "" then
    update_status()
  else
    svim:set({
      icon = { color = colors.green },
      label = { string = mode, color = colors.white },
    })
  end
end)

svim:subscribe("mouse.clicked", function()
  sbar.exec("$HOME/.config/scripts/sketchyvim-toggle.sh toggle")
end)

update_status()
