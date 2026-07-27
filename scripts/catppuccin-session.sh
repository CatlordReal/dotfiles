#!/usr/bin/env bash
set -Eeuo pipefail

ACTION="${1:-toggle}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_DIR="$CONFIG_HOME/ricing"
SESSION_STATE="$STATE_DIR/session_enabled"
JANKYBORDERS_STATE="$STATE_DIR/jankyborders_enabled"
FLAVOUR="${2:-$(cat "$STATE_DIR/theme" 2>/dev/null || printf 'mocha')}"
NVIM_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/nvim"

TILING_SCRIPT="$CONFIG_HOME/scripts/catppuccin-tiling-mode.sh"
JANKYBORDERS_SCRIPT="$CONFIG_HOME/scripts/jankyborders.sh"
SKETCHYVIM_SCRIPT="$CONFIG_HOME/scripts/sketchyvim-toggle.sh"
SKETCHYBAR_HEALTH_SCRIPT="$CONFIG_HOME/scripts/sketchybar-health.sh"
SKETCHYBAR_PLIST="$CONFIG_HOME/sketchybar/com.kianconti.sketchybar.plist"
SKETCHYBAR_LABEL="com.kianconti.sketchybar"
SKETCHYBAR_AGENT="$HOME/Library/LaunchAgents/$SKETCHYBAR_LABEL.plist"
UID_VALUE="$(id -u)"
AEROSPACE_CLIENT="${AEROSPACE_CLIENT:-/opt/homebrew/bin/aerospace}"
AEROSPACE_APP="${AEROSPACE_APP:-/Applications/AeroSpace.app}"
AEROSPACE_CONFIG="$CONFIG_HOME/aerospace/aerospace.toml"

mkdir -p "$STATE_DIR" "$HOME/Library/LaunchAgents"

normalise_flavour() {
  local value
  value="$(printf '%s' "${1:-mocha}" | tr '[:upper:]' '[:lower:]')"
  case "$value" in
    latte|frappe|macchiato|mocha) printf '%s\n' "$value" ;;
    catppuccin-latte) printf 'latte\n' ;;
    catppuccin-frappe) printf 'frappe\n' ;;
    catppuccin-macchiato) printf 'macchiato\n' ;;
    *) printf 'mocha\n' ;;
  esac
}

is_enabled() {
  [[ "$(cat "$SESSION_STATE" 2>/dev/null || printf '0')" == "1" ]]
}

mark_enabled() {
  printf '%s\n' "$1" > "$SESSION_STATE"
}

sync_neovim_theme_state() {
  local flavour="$1"
  mkdir -p "$NVIM_STATE_DIR"
  printf 'catppuccin-%s\n' "$flavour" > "$NVIM_STATE_DIR/color_theme.txt"
  printf '%s\n' "$flavour" > "$NVIM_STATE_DIR/catppuccin_flavour.txt"
}

service_loaded() {
  launchctl print "gui/$UID_VALUE/$1" >/dev/null 2>&1
}

start_aerospace() {
  [[ -x "$AEROSPACE_CLIENT" ]] || return 1
  if "$AEROSPACE_CLIENT" list-workspaces --focused >/dev/null 2>&1; then
    return 0
  fi
  if [[ -d "$AEROSPACE_APP" ]]; then
    open -gja "$AEROSPACE_APP" >/dev/null 2>&1 || return 1
  else
    open -gja AeroSpace >/dev/null 2>&1 || return 1
  fi

  local attempt
  for attempt in {1..12}; do
    "$AEROSPACE_CLIENT" list-workspaces --focused >/dev/null 2>&1 && return 0
    sleep 1
  done
  return 1
}

stop_aerospace() {
  osascript -e 'quit app "AeroSpace"' >/dev/null 2>&1 || true
}

start_sketchybar() {
  command -v sketchybar >/dev/null 2>&1 || return 1
  "$SKETCHYBAR_HEALTH_SCRIPT" ensure >/dev/null 2>&1
}

stop_sketchybar() {
  launchctl bootout "gui/$UID_VALUE/$SKETCHYBAR_LABEL" >/dev/null 2>&1 || true
  launchctl bootout "gui/$UID_VALUE" "$SKETCHYBAR_AGENT" >/dev/null 2>&1 || true
  killall sketchybar cpu_load network_load >/dev/null 2>&1 || true
  pkill -f "$CONFIG_HOME/sketchybar/sketchybarrc" >/dev/null 2>&1 || true
}

start_session() {
  local flavour
  local was_enabled
  if is_enabled; then was_enabled=1; else was_enabled=0; fi
  flavour="$(normalise_flavour "$1")"
  if ! start_aerospace; then
    mark_enabled 0
    return 1
  fi
  if ! start_sketchybar; then
    stop_aerospace
    mark_enabled 0
    return 1
  fi
  mark_enabled 1
  sync_neovim_theme_state "$flavour"
  "$TILING_SCRIPT" apply "$flavour"
  if [[ "$was_enabled" == "1" && "$(cat "$JANKYBORDERS_STATE" 2>/dev/null || printf '1')" != "1" ]]; then
    "$JANKYBORDERS_SCRIPT" suspend >/dev/null 2>&1 || true
  else
    "$JANKYBORDERS_SCRIPT" apply "$flavour" >/dev/null 2>&1 || true
  fi
  "$SKETCHYVIM_SCRIPT" apply >/dev/null 2>&1 || true
  sketchybar --trigger aerospace_workspace_change >/dev/null 2>&1 || true
}

stop_session() {
  mark_enabled 0
  "$TILING_SCRIPT" restore "$(normalise_flavour "$FLAVOUR")" >/dev/null 2>&1 || true
  "$JANKYBORDERS_SCRIPT" suspend >/dev/null 2>&1 || true
  "$SKETCHYVIM_SCRIPT" suspend >/dev/null 2>&1 || true
  stop_sketchybar
  stop_aerospace
}

apply_startup_state() {
  if is_enabled; then
    start_session "$FLAVOUR"
  else
    stop_session
  fi
}

case "$ACTION" in
  on|start|enable)
    start_session "$FLAVOUR"
    ;;
  off|stop|disable)
    stop_session
    ;;
  toggle)
    if is_enabled; then
      stop_session
    else
      start_session "$FLAVOUR"
    fi
    ;;
  startup|apply)
    apply_startup_state
    ;;
  aerospace-started)
    if is_enabled; then
      start_session "$FLAVOUR"
    fi
    ;;
  status)
    if is_enabled; then
      printf 'on\n'
    else
      printf 'off\n'
    fi
    ;;
  *)
    printf 'Usage: %s on|off|toggle|startup|status [flavour]\n' "${0##*/}" >&2
    exit 2
    ;;
esac
