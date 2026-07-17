#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CONTROL="$CONFIG_HOME/scripts/appearance-control.sh"
MENU="$CONFIG_HOME/scripts/appearance-menu.sh"
SKETCHYBAR="${SKETCHYBAR:-/opt/homebrew/bin/sketchybar}"

if [[ "${BUTTON:-left}" == "right" ]]; then
  "$CONTROL" reload-all >/tmp/appearance-control.last.log 2>&1 || true
else
  nohup "$MENU" >/tmp/appearance-menu.last.log 2>&1 &
fi

"$SKETCHYBAR" --trigger appearance_status_changed >/dev/null 2>&1 || true
