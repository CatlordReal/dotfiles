local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

sbar.add("event", "appearance_status_changed")

local popup_width = 230

local control = sbar.add("item", "appearance_control", {
  position = "right",
  update_freq = 60,
  icon = {
    string = icons.gear,
    color = colors.magenta,
    padding_left = 8,
    padding_right = 4,
  },
  label = {
    string = icons.chevron_down,
    color = colors.grey,
    font = { size = 10.0 },
    padding_left = 0,
    padding_right = 8,
  },
  background = { color = colors.bg1 },
  popup = { align = "center" },
})

sbar.add("item", "appearance_padding", {
  position = "right",
  width = settings.group_paddings,
})

local function popup_item(name, icon, label, click_script)
  return sbar.add("item", "appearance_popup_" .. name, {
    position = "popup." .. control.name,
    width = popup_width,
    align = "center",
    icon = {
      string = icon,
      width = 28,
      align = "left",
      padding_left = 8,
      padding_right = 4,
      color = colors.grey,
    },
    label = {
      string = label,
      align = "left",
      width = popup_width - 46,
      padding_left = 0,
      padding_right = 8,
    },
    background = { height = 24, color = colors.transparent },
    click_script = click_script,
  })
end

local title = popup_item("title", icons.gear, "Appearance", "")
local latte = popup_item("latte", icons.sun, "Latte", "$HOME/.config/scripts/appearance-control.sh theme latte")
local frappe = popup_item("frappe", "●", "Frappe", "$HOME/.config/scripts/appearance-control.sh theme frappe")
local macchiato = popup_item("macchiato", "●", "Macchiato", "$HOME/.config/scripts/appearance-control.sh theme macchiato")
local mocha = popup_item("mocha", icons.moon, "Mocha", "$HOME/.config/scripts/appearance-control.sh theme mocha")
local auto = popup_item("auto", icons.switch.off, "Auto macOS appearance", "$HOME/.config/scripts/appearance-control.sh toggle-auto")
local session = popup_item("session", icons.switch.off, "Rice session", "$HOME/.config/scripts/appearance-control.sh toggle-session")
local opacity_title = popup_item("opacity_title", "􀍠", "Kitty opacity", "")
local opacity_60 = popup_item("opacity_60", "60", "Soft glass", "$HOME/.config/scripts/appearance-control.sh opacity 60")
local opacity_70 = popup_item("opacity_70", "70", "Default glass", "$HOME/.config/scripts/appearance-control.sh opacity 70")
local opacity_85 = popup_item("opacity_85", "85", "Subtle glass", "$HOME/.config/scripts/appearance-control.sh opacity 85")
local opacity_100 = popup_item("opacity_100", "100", "Opaque", "$HOME/.config/scripts/appearance-control.sh opacity 100")
local sounds = popup_item("sounds", icons.sound, "Sounds", "$HOME/.config/scripts/appearance-control.sh toggle-sounds")
local reload = popup_item("reload", "􀅈", "Reload all", "$HOME/.config/scripts/appearance-control.sh reload-all")

local flavour_items = {
  latte = latte,
  frappe = frappe,
  macchiato = macchiato,
  mocha = mocha,
}

local opacity_items = {
  ["0.60"] = opacity_60,
  ["0.70"] = opacity_70,
  ["0.85"] = opacity_85,
  ["1.00"] = opacity_100,
}

local function parse_status(output)
  local status = {}
  for line in (output or ""):gmatch("[^\r\n]+") do
    local key, value = line:match("^([%w_]+)=(.*)$")
    if key then status[key] = value end
  end
  return status
end

local function update_status()
  sbar.exec("$HOME/.config/scripts/appearance-control.sh auto-sync >/dev/null 2>&1; $HOME/.config/scripts/appearance-control.sh status", function(output)
    local status = parse_status(output)
    local theme = status.theme or "mocha"
    local opacity = status.opacity or "0.70"
    local auto_on = status.auto == "on"
    local sound_on = status.sounds == "on"
    local session_on = status.session == "on"

    control:set({
      icon = { color = theme == "latte" and colors.yellow or colors.magenta },
    })

    title:set({ label = "Appearance · " .. theme })
    auto:set({
      icon = { string = auto_on and icons.switch.on or icons.switch.off, color = auto_on and colors.green or colors.grey },
      label = "Auto macOS appearance " .. (auto_on and "on" or "off"),
    })
    sounds:set({
      icon = { color = sound_on and colors.green or colors.grey },
      label = "Sounds " .. (sound_on and "on" or "off"),
    })
    session:set({
      icon = { string = session_on and icons.switch.on or icons.switch.off, color = session_on and colors.green or colors.grey },
      label = "Rice session " .. (session_on and "on" or "off"),
    })

    for name, item in pairs(flavour_items) do
      local active = name == theme
      item:set({
        icon = { color = active and colors.magenta or colors.grey },
        label = { color = active and colors.white or colors.grey },
        background = { color = active and colors.with_alpha(colors.bg2, 0.85) or colors.transparent },
      })
    end

    for value, item in pairs(opacity_items) do
      local active = value == opacity
      item:set({
        icon = { color = active and colors.blue or colors.grey },
        label = { color = active and colors.white or colors.grey },
        background = { color = active and colors.with_alpha(colors.bg2, 0.85) or colors.transparent },
      })
    end
  end)
end

local function set_popup(drawing)
  control:set({ popup = { drawing = drawing } })
  sbar.animate("tanh", 18, function()
    control:set({
      label = { string = drawing and icons.chevron_up or icons.chevron_down },
      background = { color = drawing and colors.bg2 or colors.bg1 },
    })
  end)
end

control:subscribe({ "forced", "routine", "system_woke", "appearance_status_changed" }, update_status)

control:subscribe("mouse.clicked", function()
  local should_draw = control:query().popup.drawing == "off"
  if should_draw then update_status() end
  set_popup(should_draw)
end)

control:subscribe("mouse.exited.global", function()
  set_popup(false)
end)

control:subscribe("mouse.entered", function()
  sbar.animate("tanh", 14, function()
    control:set({ background = { color = colors.bg2 } })
  end)
end)

control:subscribe("mouse.exited", function()
  if control:query().popup.drawing == "off" then
    sbar.animate("tanh", 14, function()
      control:set({ background = { color = colors.bg1 } })
    end)
  end
end)

opacity_title:set({ icon = { color = colors.blue }, label = { color = colors.white } })
session:set({ icon = { color = colors.green } })
reload:set({ icon = { color = colors.orange } })
update_status()
