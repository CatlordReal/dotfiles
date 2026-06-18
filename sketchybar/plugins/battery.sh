#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/colors.sh"

battery_line="$(pmset -g batt | awk 'NR==2 { print }')"
percent="$(printf '%s\n' "$battery_line" | grep -Eo '[0-9]+%' | head -n 1)"
status="Battery"
icon="󰁹"
color="$TEXT"

case "$battery_line" in
  *"AC Power"*|*"charging"*)
    icon="󰂄"
    color="$SUCCESS"
    ;;
esac

number="${percent%%%}"
if [[ -n "$number" && "$number" -le 20 ]]; then
  icon="󰂃"
  color="$ERROR"
elif [[ -n "$number" && "$number" -le 45 ]]; then
  icon="󰁾"
  color="$WARN"
fi

if [[ -z "$percent" ]]; then
  percent="--%"
  status="Power"
fi

sketchybar --set "$NAME" icon="$icon" icon.color="$color" label="$percent" drawing=on
