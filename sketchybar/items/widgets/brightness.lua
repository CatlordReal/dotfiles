local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

local brightness = sbar.add("item", "widgets.brightness", {
  position = "right",
  update_freq = 20,
  icon = {
    string = icons.brightness,
    color = colors.yellow,
    padding_left = 7,
    padding_right = 4,
  },
  label = {
    string = "--%",
    color = colors.white,
    width = 28,
    align = "right",
    font = {
      family = settings.font.numbers,
      style = settings.font.style_map["Bold"],
      size = 9.0,
    },
    padding_left = 0,
    padding_right = 7,
  },
})

local function update_brightness()
  sbar.exec([[command -v brightness >/dev/null 2>&1 && brightness -l 2>/dev/null | awk '/brightness/ {printf "%d", ($NF * 100) + 0.5; found=1; exit} END {if (!found) printf "--"}']], function(result)
    local value = (result or ""):gsub("%s+", "")
    brightness:set({ label = value ~= "" and (value .. "%") or "--%" })
  end)
end

local function change_brightness(delta)
  sbar.exec([[current=$(brightness -l 2>/dev/null | awk '/brightness/ {print $NF; exit}'); if [ -n "$current" ]; then next=$(awk -v c="$current" -v d="]] .. delta .. [[" 'BEGIN {v=c+d; if (v<0) v=0; if (v>1) v=1; printf "%.2f", v}'); brightness "$next" >/dev/null 2>&1; fi]], update_brightness)
end

brightness:subscribe({ "forced", "routine", "system_woke" }, update_brightness)
brightness:subscribe("mouse.clicked", function()
  sbar.exec("open 'x-apple.systempreferences:com.apple.Displays-Settings.extension'")
end)
brightness:subscribe("mouse.scrolled", function(env)
  local delta = (env.INFO.delta > 0) and 0.05 or -0.05
  change_brightness(delta)
end)

sbar.add("bracket", "widgets.brightness.bracket", { brightness.name }, {
  background = { color = colors.bg1 }
})

sbar.add("item", "widgets.brightness.padding", {
  position = "right",
  width = settings.group_paddings
})
