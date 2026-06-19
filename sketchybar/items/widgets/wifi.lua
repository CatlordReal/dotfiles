local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

local popup_width = 250
local active_interface = "en0"
local active_port = "Wi-Fi"

local function shell_quote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function detect_interface_sync()
  local handle = io.popen([[iface=$(route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}'); if [ -z "$iface" ]; then iface=en0; fi; port=$(networksetup -listallhardwareports 2>/dev/null | awk -v dev="$iface" 'prev=="Hardware Port:" {port=$0; sub(/^Hardware Port: /,"",port)} $1=="Device:" && $2==dev {print port; exit} {prev=$1" "$2}'); printf '%s|%s' "$iface" "${port:-Network}" ]])
  if not handle then return end
  local output = handle:read("*a") or ""
  handle:close()
  local iface, port = output:match("^([^|]+)|(.+)$")
  if iface and iface ~= "" then active_interface = iface end
  if port and port ~= "" then active_port = port end
end

local function start_provider()
  sbar.exec("killall network_load >/dev/null 2>&1; $CONFIG_DIR/helpers/event_providers/network_load/bin/network_load " .. shell_quote(active_interface) .. " network_update 2.0")
end

detect_interface_sync()
start_provider()

local network_up = sbar.add("item", "widgets.network.up", {
  position = "right",
  padding_left = -5,
  width = 0,
  icon = {
    padding_right = 0,
    font = {
      style = settings.font.style_map["Bold"],
      size = 9.0,
    },
    string = icons.wifi.upload,
  },
  label = {
    font = {
      family = settings.font.numbers,
      style = settings.font.style_map["Bold"],
      size = 9.0,
    },
    color = colors.red,
    string = "000 Bps",
  },
  y_offset = 4,
})

local network_down = sbar.add("item", "widgets.network.down", {
  position = "right",
  padding_left = -5,
  icon = {
    padding_right = 0,
    font = {
      style = settings.font.style_map["Bold"],
      size = 9.0,
    },
    string = icons.wifi.download,
  },
  label = {
    font = {
      family = settings.font.numbers,
      style = settings.font.style_map["Bold"],
      size = 9.0,
    },
    color = colors.blue,
    string = "000 Bps",
  },
  y_offset = -4,
})

local network = sbar.add("item", "widgets.network", {
  position = "right",
  label = { drawing = false },
})

local network_bracket = sbar.add("bracket", "widgets.network.bracket", {
  network.name,
  network_up.name,
  network_down.name
}, {
  background = { color = colors.bg1 },
  popup = { align = "center", height = 30 }
})

local interface_name = sbar.add("item", {
  position = "popup." .. network_bracket.name,
  icon = {
    font = { style = settings.font.style_map["Bold"] },
    string = icons.wifi.router,
  },
  width = popup_width,
  align = "center",
  label = {
    font = { size = 15, style = settings.font.style_map["Bold"] },
    max_chars = 22,
    string = active_port .. " (" .. active_interface .. ")",
  },
  background = {
    height = 2,
    color = colors.grey,
    y_offset = -15
  }
})

local hostname = sbar.add("item", {
  position = "popup." .. network_bracket.name,
  icon = { align = "left", string = "Hostname:", width = popup_width / 2 },
  label = { max_chars = 20, string = "????????????", width = popup_width / 2, align = "right" }
})

local ip = sbar.add("item", {
  position = "popup." .. network_bracket.name,
  icon = { align = "left", string = "IP:", width = popup_width / 2 },
  label = { string = "???.???.???.???", width = popup_width / 2, align = "right" }
})

local router = sbar.add("item", {
  position = "popup." .. network_bracket.name,
  icon = { align = "left", string = "Router:", width = popup_width / 2 },
  label = { string = "???.???.???.???", width = popup_width / 2, align = "right" },
})

sbar.add("item", { position = "right", width = settings.group_paddings })

local function update_interface()
  sbar.exec([[iface=$(route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}'); if [ -z "$iface" ]; then iface=en0; fi; port=$(networksetup -listallhardwareports 2>/dev/null | awk -v dev="$iface" 'prev=="Hardware Port:" {port=$0; sub(/^Hardware Port: /,"",port)} $1=="Device:" && $2==dev {print port; exit} {prev=$1" "$2}'); printf '%s|%s' "$iface" "${port:-Network}"]], function(result)
    local iface, port = (result or ""):match("^([^|]+)|(.+)$")
    if iface and iface ~= "" and iface ~= active_interface then
      active_interface = iface
      active_port = port or "Network"
      start_provider()
    elseif port and port ~= "" then
      active_port = port
    end

    local is_wifi = active_port:lower():find("wi%-?fi") ~= nil
    network:set({
      icon = {
        string = is_wifi and icons.wifi.connected or icons.wifi.router,
        color = colors.white,
      },
    })
    interface_name:set({ label = active_port .. " (" .. active_interface .. ")" })
  end)
end

network_up:subscribe("network_update", function(env)
  local up_color = (env.upload == "000 Bps") and colors.grey or colors.red
  local down_color = (env.download == "000 Bps") and colors.grey or colors.blue
  network_up:set({
    icon = { color = up_color },
    label = { string = env.upload, color = up_color }
  })
  network_down:set({
    icon = { color = down_color },
    label = { string = env.download, color = down_color }
  })
end)

network:subscribe({"wifi_change", "system_woke", "routine"}, update_interface)
network:set({ update_freq = 30 })

local function hide_details()
  network_bracket:set({ popup = { drawing = false } })
end

local function toggle_details()
  local should_draw = network_bracket:query().popup.drawing == "off"
  if should_draw then
    update_interface()
    network_bracket:set({ popup = { drawing = true }})
    sbar.exec("networksetup -getcomputername", function(result)
      hostname:set({ label = result })
    end)
    sbar.exec("ipconfig getifaddr " .. shell_quote(active_interface), function(result)
      ip:set({ label = result ~= "" and result or "No address" })
    end)
    sbar.exec("route -n get default 2>/dev/null | awk '/gateway:/{print $2; exit}'", function(result)
      router:set({ label = result ~= "" and result or "No router" })
    end)
  else
    hide_details()
  end
end

network_up:subscribe("mouse.clicked", toggle_details)
network_down:subscribe("mouse.clicked", toggle_details)
network:subscribe("mouse.clicked", toggle_details)
network:subscribe("mouse.exited.global", hide_details)

local function copy_label_to_clipboard(env)
  local label = sbar.query(env.NAME).label.value
  sbar.exec("echo " .. shell_quote(label) .. " | pbcopy")
  sbar.set(env.NAME, { label = { string = icons.clipboard, align="center" } })
  sbar.delay(1, function()
    sbar.set(env.NAME, { label = { string = label, align = "right" } })
  end)
end

interface_name:subscribe("mouse.clicked", copy_label_to_clipboard)
hostname:subscribe("mouse.clicked", copy_label_to_clipboard)
ip:subscribe("mouse.clicked", copy_label_to_clipboard)
router:subscribe("mouse.clicked", copy_label_to_clipboard)
