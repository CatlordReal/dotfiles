#!/usr/bin/env bash
set -Eeuo pipefail

label="${INFO:-}"
if [[ -z "$label" ]]; then
  label="$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null || printf 'Desktop')"
fi

sketchybar --set "$NAME" label="$label"
