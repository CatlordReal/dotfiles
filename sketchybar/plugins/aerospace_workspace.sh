#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/colors.sh"

workspace="${NAME#space.}"
focused="${FOCUSED_WORKSPACE:-}"

if [[ -z "$focused" ]] && command -v aerospace >/dev/null 2>&1; then
  focused="$(aerospace list-workspaces --focused 2>/dev/null || true)"
fi

window_count="0"
if command -v aerospace >/dev/null 2>&1; then
  window_count="$(aerospace list-windows --workspace "$workspace" --count 2>/dev/null || printf '0')"
fi

if [[ "$focused" == "$workspace" ]]; then
  sketchybar --set "$NAME" \
    icon.color="$CRUST" \
    background.color="$ACCENT" \
    background.border_color="$ACCENT" \
    label.drawing=off
elif [[ "$window_count" != "0" ]]; then
  sketchybar --set "$NAME" \
    icon.color="$TEXT" \
    background.color="$ITEM_BG_ALT" \
    background.border_color="$BORDER" \
    label.drawing=off
else
  sketchybar --set "$NAME" \
    icon.color="$MUTED" \
    background.color="$ITEM_BG" \
    background.border_color="$ITEM_BG" \
    label.drawing=off
fi
