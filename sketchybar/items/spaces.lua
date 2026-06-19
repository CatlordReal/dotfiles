local colors = require("colors")
local icons = require("icons")
local settings = require("settings")
local app_icons = require("helpers.app_icons")

local workspace_names = { "1", "2", "3", "4", "5", "6", "7", "8", "9" }
local spaces = {}
local space_paddings = {}
local focused_workspace = "1"
local showing_spaces = false

local function app_icon(app)
  return app_icons[app] or app_icons["Default"] or ":default:"
end

for _, workspace in ipairs(workspace_names) do
  local space = sbar.add("item", "space." .. workspace, {
    drawing = false,
    icon = {
      font = { family = settings.font.numbers },
      string = workspace,
      padding_left = 15,
      padding_right = 8,
      color = colors.grey,
    },
    label = {
      padding_right = 16,
      color = colors.grey,
      font = "sketchybar-app-font:Regular:15.0",
      y_offset = -1,
      width = 58,
      align = "left",
      max_chars = 18,
    },
    padding_right = 1,
    padding_left = 1,
    click_script = "aerospace workspace " .. workspace,
    background = {
      color = colors.bg1,
      border_width = 1,
      height = 26,
      border_color = colors.black,
    },
  })

  spaces[workspace] = space

  space_paddings[workspace] = sbar.add("item", "space.padding." .. workspace, {
    drawing = false,
    width = settings.group_paddings,
  })

  space:subscribe("mouse.clicked", function(env)
    if env.BUTTON == "right" then
      sbar.exec("aerospace move-node-to-workspace " .. workspace)
    else
      sbar.exec("aerospace workspace " .. workspace)
    end
  end)
end

local spaces_indicator = sbar.add("item", "spaces.indicator", {
  updates = true,
  padding_left = -3,
  padding_right = 0,
  icon = {
    padding_left = 8,
    padding_right = 9,
    color = colors.grey,
    string = icons.switch.off,
  },
  label = {
    width = 0,
    padding_left = 0,
    padding_right = 8,
    string = "Spaces",
    color = colors.bg1,
  },
  background = {
    color = colors.with_alpha(colors.grey, 0.0),
    border_color = colors.with_alpha(colors.bg1, 0.0),
  }
})

local watcher = sbar.add("item", "spaces.watcher", {
  drawing = false,
  update_freq = 5,
  updates = true,
})

local function parse_workspace_state(output)
  local workspace_apps = {}
  local workspace_counts = {}
  local workspace_monitors = {}
  local highest_used = 1

  for _, workspace in ipairs(workspace_names) do
    workspace_apps[workspace] = ""
    workspace_counts[workspace] = 0
    workspace_monitors[workspace] = ""
  end

  local section = "workspaces"
  for line in (output or ""):gmatch("[^\r\n]+") do
    if line == "--WINDOWS--" then
      section = "windows"
    else
      local key, value = line:match("^FOCUSED=(.+)$")
      if key then
        focused_workspace = key
        highest_used = math.max(highest_used, tonumber(key) or 1)
      elseif section == "workspaces" then
        local workspace, monitor = line:match("^([^|]+)|(.+)$")
        if workspace_monitors[workspace] then
          workspace_monitors[workspace] = monitor
        end
      else
        local workspace, app = line:match("^([^|]+)|(.+)$")
        if workspace_apps[workspace] and app and app ~= "" then
          workspace_counts[workspace] = workspace_counts[workspace] + 1
          highest_used = math.max(highest_used, tonumber(workspace) or 1)
          local icon = app_icon(app)
          if not workspace_apps[workspace]:find(icon, 1, true) then
            workspace_apps[workspace] = workspace_apps[workspace] .. icon
          end
        end
      end
    end
  end

  local focused_has_windows = (workspace_counts[focused_workspace] or 0) > 0
  sbar.set("/widgets\\..*/", { drawing = focused_has_windows })

  local visible_limit = 4
  if highest_used >= 4 then
    visible_limit = math.min(9, highest_used + 1)
  end

  for workspace, item in pairs(spaces) do
    local workspace_number = tonumber(workspace) or 1
    local selected = workspace == focused_workspace
    local has_windows = (workspace_counts[workspace] or 0) > 0
    local should_show = showing_spaces and workspace_number <= visible_limit
    local label = workspace_apps[workspace]
    if label == "" then label = " —" end

    item:set({ drawing = should_show })
    space_paddings[workspace]:set({ drawing = should_show })

    sbar.animate("tanh", 12, function()
      item:set({
        icon = {
          color = selected and colors.red or (has_windows and colors.white or colors.grey),
        },
        label = {
          string = label,
          color = selected and colors.white or colors.grey,
        },
        background = {
          border_color = selected and colors.grey or colors.bg2,
          color = has_windows and colors.bg1 or colors.with_alpha(colors.bg1, 0.65),
        },
      })
    end)
  end
end

local function update_spaces()
  sbar.exec([[focused=$(aerospace list-workspaces --focused 2>/dev/null); printf 'FOCUSED=%s\n' "$focused"; aerospace list-workspaces --all --format '%{workspace}|%{monitor-id}' 2>/dev/null; printf '%s\n' '--WINDOWS--'; aerospace list-windows --all --format '%{workspace}|%{app-name}' 2>/dev/null]], parse_workspace_state)
end

watcher:subscribe({ "routine", "aerospace_workspace_change", "front_app_switched", "system_woke" }, function(env)
  if env and env.FOCUSED_WORKSPACE then
    focused_workspace = env.FOCUSED_WORKSPACE
  end
  update_spaces()
end)

spaces_indicator:subscribe("swap_menus_and_spaces", function(env)
  showing_spaces = not showing_spaces
  spaces_indicator:set({
    icon = showing_spaces and icons.switch.on or icons.switch.off
  })
  update_spaces()
end)

spaces_indicator:subscribe("mouse.entered", function(env)
  sbar.animate("tanh", 30, function()
    spaces_indicator:set({
      background = {
        color = { alpha = 1.0 },
        border_color = { alpha = 1.0 },
      },
      icon = { color = colors.bg1 },
      label = { width = "dynamic" }
    })
  end)
end)

spaces_indicator:subscribe("mouse.exited", function(env)
  sbar.animate("tanh", 30, function()
    spaces_indicator:set({
      background = {
        color = { alpha = 0.0 },
        border_color = { alpha = 0.0 },
      },
      icon = { color = colors.grey },
      label = { width = 0, }
    })
  end)
end)

spaces_indicator:subscribe("mouse.clicked", function(env)
  sbar.trigger("swap_menus_and_spaces")
end)

update_spaces()
