#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CONTROL="$CONFIG_HOME/scripts/appearance-control.sh"
SKETCHYBAR="${SKETCHYBAR:-/opt/homebrew/bin/sketchybar}"

choose() {
  local title="$1"
  local prompt="$2"
  shift 2

  /usr/bin/osascript <<OSA
tell application "System Events" to activate
set choices to {$(printf '"%s",' "$@" | sed 's/,$//')}
set picked to choose from list choices with title "$title" with prompt "$prompt" OK button name "Select" cancel button name "Cancel"
if picked is false then
  return ""
else
  return item 1 of picked
end if
OSA
}

notify_bar() {
  "$SKETCHYBAR" --trigger appearance_status_changed >/dev/null 2>&1 || true
}

run_action() {
  "$CONTROL" "$@" >/tmp/appearance-control.last.log 2>&1 || true
  notify_bar
}

main="$(choose "Catppuccin Rice" "Choose action" \
  "Colour theme" \
  "Kitty opacity" \
  "Toggle rice session" \
  "Toggle auto appearance" \
  "Toggle sounds" \
  "Reload all")"

case "$main" in
  "Colour theme")
    theme="$(choose "Colour theme" "Choose Catppuccin flavour" \
      "Latte 🌻" \
      "Frappe 🪴" \
      "Macchiato 🌺" \
      "Mocha 🌿")"
    case "$theme" in
      "Latte "*) run_action theme latte ;;
      "Frappe "*) run_action theme frappe ;;
      "Macchiato "*) run_action theme macchiato ;;
      "Mocha "*) run_action theme mocha ;;
    esac
    ;;
  "Kitty opacity")
    opacity="$(choose "Kitty opacity" "Choose background opacity" \
      "60%" \
      "70%" \
      "85%" \
      "100%")"
    case "$opacity" in
      "60%") run_action opacity 60 ;;
      "70%") run_action opacity 70 ;;
      "85%") run_action opacity 85 ;;
      "100%") run_action opacity 100 ;;
    esac
    ;;
  "Toggle rice session")
    run_action toggle-session
    ;;
  "Toggle auto appearance")
    run_action toggle-auto
    ;;
  "Toggle sounds")
    run_action toggle-sounds
    ;;
  "Reload all")
    run_action reload-all
    ;;
esac
