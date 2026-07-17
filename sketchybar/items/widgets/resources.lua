local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

sbar.exec("killall cpu_load >/dev/null 2>&1 || true")

local resources = sbar.add("item", "widgets.resources", {
  position = "right",
  update_freq = 4,
  icon = {
    string = icons.memory,
    color = colors.green,
    padding_left = 7,
    padding_right = 5,
  },
  label = {
    string = "mem --%  gpu --%  cpu --%",
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

local function memory_percent(output)
  local pages = {}
  for label, value in (output or ""):gmatch("([%a%s]+):%s+([%d%.]+)") do
    pages[label] = tonumber(value) or 0
  end
  local total = (pages["Pages free"] or 0) + (pages["Pages speculative"] or 0)
    + (pages["Pages active"] or 0) + (pages["Pages wired down"] or 0)
    + (pages["Pages occupied by compressor"] or 0) + (pages["Pages inactive"] or 0)
  local used = (pages["Pages active"] or 0) + (pages["Pages wired down"] or 0)
    + (pages["Pages occupied by compressor"] or 0)
  return total > 0 and math.floor((used / total) * 100 + 0.5) or 0
end

local function metric_color(value)
  if value >= 90 then return colors.red end
  if value >= 75 then return colors.orange end
  if value >= 55 then return colors.yellow end
  return colors.green
end

local function update_resources()
  sbar.exec("vm_stat", function(memory_output)
    local memory = memory_percent(memory_output)
    sbar.exec([[ioreg -r -l -w 0 -c IOGPU 2>/dev/null | sed -n 's/.*"Device Utilization %"=\([0-9][0-9]*\).*/\1/p' | head -n 1]], function(gpu_output)
      local gpu = tonumber((gpu_output or ""):match("(%d+)")) or 0
      sbar.exec([[top -l 1 2>/dev/null | awk -F'[:,%%]' '/CPU usage:/ {printf "%d", $2 + $4; exit}']], function(cpu_output)
        local cpu = tonumber((cpu_output or ""):match("(%d+)")) or 0
        local peak = math.max(memory, gpu, cpu)
        resources:set({
          icon = { color = metric_color(peak) },
          label = {
            string = string.format("mem %d%%  gpu %d%%  cpu %d%%", memory, gpu, cpu),
            color = metric_color(peak),
          },
        })
      end)
    end)
  end)
end

resources:subscribe({ "forced", "routine", "system_woke" }, update_resources)
resources:subscribe("mouse.clicked", function()
  sbar.exec("open -a 'Activity Monitor'")
end)

sbar.add("bracket", "widgets.resources.bracket", { resources.name }, {
  background = { color = colors.bg1 },
})

sbar.add("item", "widgets.resources.padding", {
  position = "right",
  width = settings.group_paddings,
})
