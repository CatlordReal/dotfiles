local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

local weather = sbar.add("item", "widgets.weather", {
  position = "right",
  update_freq = 900,
  icon = {
    string = icons.weather,
    color = colors.blue,
    padding_left = 7,
    padding_right = 4,
  },
  label = {
    string = "--",
    color = colors.white,
    max_chars = 12,
    font = {
      family = settings.font.numbers,
      style = settings.font.style_map["Bold"],
      size = 9.0,
    },
    padding_left = 0,
    padding_right = 7,
  },
})

local function update_weather()
  local cmd = [[loc="${SKETCHYBAR_WEATHER_LOCATION:-}"; if [ -n "$loc" ]; then url="https://wttr.in/${loc}?format=%c+%t"; else url="https://wttr.in/?format=%c+%t"; fi; curl -m 4 -fsS "$url" 2>/dev/null | tr -d '\n' | sed 's/+//g']]
  sbar.exec(cmd, function(result)
    result = (result or ""):gsub("^%s+", ""):gsub("%s+$", "")
    weather:set({ label = result ~= "" and result or "--" })
  end)
end

weather:subscribe({ "forced", "routine", "system_woke" }, update_weather)
weather:subscribe("mouse.clicked", function()
  sbar.exec([[loc="${SKETCHYBAR_WEATHER_LOCATION:-}"; open "https://wttr.in/${loc}"]])
end)

sbar.add("bracket", "widgets.weather.bracket", { weather.name }, {
  background = { color = colors.bg1 }
})

sbar.add("item", "widgets.weather.padding", {
  position = "right",
  width = settings.group_paddings
})
