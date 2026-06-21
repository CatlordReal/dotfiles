local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

local gpu = sbar.add("item", "widgets.gpu", {
  position = "right",
  update_freq = 3,
  icon = {
    string = icons.gpu,
    color = colors.magenta,
    padding_left = 7,
    padding_right = 4,
  },
  label = {
    string = "gpu ??%",
    color = colors.white,
    font = {
      family = settings.font.numbers,
      style = settings.font.style_map["Bold"],
      size = 9.0,
    },
    padding_left = 0,
    padding_right = 7,
  },
})

local function update_gpu()
  sbar.exec([[ioreg -r -c AGXAccelerator -d 1 2>/dev/null | sed -n 's/.*"Device Utilization %"=\([0-9][0-9]*\).*/\1/p' | head -n 1]], function(output)
    local load = tonumber((output or ""):match("(%d+)")) or 0
    local color = colors.magenta

    if load >= 85 then
      color = colors.red
    elseif load >= 65 then
      color = colors.orange
    elseif load >= 40 then
      color = colors.yellow
    end

    gpu:set({
      icon = { color = color },
      label = {
        string = "gpu " .. load .. "%",
        color = color,
      },
    })
  end)
end

gpu:subscribe({ "forced", "routine", "system_woke" }, update_gpu)

gpu:subscribe("mouse.clicked", function()
  sbar.exec("open -a 'Activity Monitor'")
end)

sbar.add("bracket", "widgets.gpu.bracket", { gpu.name }, {
  background = { color = colors.bg1 }
})

sbar.add("item", "widgets.gpu.padding", {
  position = "right",
  width = settings.group_paddings
})
