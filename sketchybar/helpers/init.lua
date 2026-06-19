-- Add the sketchybar module to the package cpath
package.cpath = package.cpath .. ";/Users/" .. os.getenv("USER") .. "/.local/share/sketchybar_lua/?.so"

local config_dir = CONFIG_DIR or os.getenv("CONFIG_DIR") or (os.getenv("HOME") .. "/.config/sketchybar")
os.execute("(cd " .. config_dir .. "/helpers && make)")
