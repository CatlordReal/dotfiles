local config_home = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local theme_file = config_home .. "/ricing/theme"
local active_theme_file = config_home .. "/sketchybar/helpers/active_theme.txt"

local palettes = {
  latte = {
    black = 0xffdce0e8,
    white = 0xff4c4f69,
    red = 0xffd20f39,
    green = 0xff40a02b,
    blue = 0xff1e66f5,
    yellow = 0xffdf8e1d,
    orange = 0xfffe640b,
    magenta = 0xff8839ef,
    grey = 0xff9ca0b0,
    bar_bg = 0xdceff1f5,
    bg1 = 0xe6e6e9ef,
    bg2 = 0xd9ccd0da,
    popup_bg = 0xddeff1f5,
    popup_border = 0xff9ca0b0,
  },
  frappe = {
    black = 0xff232634,
    white = 0xffc6d0f5,
    red = 0xffe78284,
    green = 0xffa6d189,
    blue = 0xff8caaee,
    yellow = 0xffe5c890,
    orange = 0xffef9f76,
    magenta = 0xffca9ee6,
    grey = 0xff737994,
    bar_bg = 0xdc303446,
    bg1 = 0xe6414559,
    bg2 = 0xd951576d,
    popup_bg = 0xdd303446,
    popup_border = 0xff737994,
  },
  macchiato = {
    black = 0xff181926,
    white = 0xffcad3f5,
    red = 0xffed8796,
    green = 0xffa6da95,
    blue = 0xff8aadf4,
    yellow = 0xffeed49f,
    orange = 0xfff5a97f,
    magenta = 0xffc6a0f6,
    grey = 0xff6e738d,
    bar_bg = 0xdc24273a,
    bg1 = 0xe6363a4f,
    bg2 = 0xd9494d64,
    popup_bg = 0xdd24273a,
    popup_border = 0xff6e738d,
  },
  mocha = {
    black = 0xff11111b,
    white = 0xffcdd6f4,
    red = 0xfff38ba8,
    green = 0xffa6e3a1,
    blue = 0xff89b4fa,
    yellow = 0xfff9e2af,
    orange = 0xfffab387,
    magenta = 0xffcba6f7,
    grey = 0xff6c7086,
    bar_bg = 0xdc1e1e2e,
    bg1 = 0xe6313244,
    bg2 = 0xd945475a,
    popup_bg = 0xdd1e1e2e,
    popup_border = 0xff6c7086,
  },
}

local function read_theme(path)
  local file = io.open(path, "r")
  if not file then return nil end
  local value = file:read("*all"):gsub("%s+", ""):lower()
  file:close()
  return palettes[value] and value or nil
end

local active = read_theme(theme_file) or read_theme(active_theme_file) or "mocha"
local selected = palettes[active]

local colors = {
  black = selected.black,
  white = selected.white,
  red = selected.red,
  green = selected.green,
  blue = selected.blue,
  yellow = selected.yellow,
  orange = selected.orange,
  magenta = selected.magenta,
  grey = selected.grey,
  transparent = 0x00000000,
  active_theme = active,

  bar = {
    bg = selected.bar_bg,
    border = selected.bg2,
  },
  popup = {
    bg = selected.popup_bg,
    border = selected.popup_border,
  },
  bg1 = selected.bg1,
  bg2 = selected.bg2,
}

colors.with_alpha = function(color, alpha)
  if alpha > 1.0 or alpha < 0.0 then return color end
  return (color & 0x00ffffff) | (math.floor(alpha * 255.0) << 24)
end

return colors
