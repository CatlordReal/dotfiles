#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ricing"
source "$CONFIG_DIR/colors.sh"

active="$(cat "$STATE_DIR/active" 2>/dev/null || printf '0')"
theme="$(cat "$STATE_DIR/theme" 2>/dev/null || printf '%s' "$CATPPUCCIN_FLAVOUR")"

case "$theme" in
  latte) label="Latte" ;;
  frappe) label="Frappe" ;;
  macchiato) label="Macchiato" ;;
  *) label="Mocha" ;;
esac

if [[ "$active" == "1" ]]; then
  sketchybar --set "$NAME" icon="󰘧" icon.color="$ACCENT" label="$label" background.color="$ITEM_BG_ALT"
else
  sketchybar --set "$NAME" icon="󰘦" icon.color="$MUTED" label="Desktop" background.color="$ITEM_BG"
fi
