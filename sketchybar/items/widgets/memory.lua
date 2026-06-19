local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

local memory = sbar.add("item", "widgets.memory", {
  position = "right",
  update_freq = 10,
  icon = {
    string = icons.memory,
    color = colors.green,
    padding_left = 7,
    padding_right = 4,
  },
  label = {
    string = "mem ??%",
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

local function parse_pages(output, label)
  local value = output:match(label .. ":%s+([%d%.]+)")
  return tonumber(value) or 0
end

local function update_memory()
  sbar.exec("vm_stat", function(output)
    local free = parse_pages(output, "Pages free")
    local speculative = parse_pages(output, "Pages speculative")
    local active = parse_pages(output, "Pages active")
    local wired = parse_pages(output, "Pages wired down")
    local compressed = parse_pages(output, "Pages occupied by compressor")
    local inactive = parse_pages(output, "Pages inactive")

    local total = free + speculative + active + wired + compressed + inactive
    local used = active + wired + compressed
    local percent = total > 0 and math.floor((used / total) * 100 + 0.5) or 0
    local color = colors.green

    if percent >= 90 then
      color = colors.red
    elseif percent >= 80 then
      color = colors.orange
    elseif percent >= 70 then
      color = colors.yellow
    end

    memory:set({
      icon = { color = color },
      label = {
        string = "mem " .. percent .. "%",
        color = color,
      },
    })
  end)
end

memory:subscribe({ "forced", "routine", "system_woke" }, update_memory)

sbar.add("bracket", "widgets.memory.bracket", { memory.name }, {
  background = { color = colors.bg1 }
})

sbar.add("item", "widgets.memory.padding", {
  position = "right",
  width = settings.group_paddings
})
