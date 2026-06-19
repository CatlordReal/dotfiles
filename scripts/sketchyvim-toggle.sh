#!/usr/bin/env bash
set -Eeuo pipefail

ACTION="${1:-toggle}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_DIR="$CONFIG_HOME/ricing"
SVIM_DIR="$CONFIG_HOME/svim"
PLIST="$SVIM_DIR/com.kianconti.svim.plist"
LABEL="com.kianconti.svim"
UID_VALUE="$(id -u)"

mkdir -p "$STATE_DIR" "$SVIM_DIR"

is_running() {
  launchctl print "gui/$UID_VALUE/$LABEL" >/dev/null 2>&1
}

mark_enabled() {
  printf '%s\n' "$1" > "$STATE_DIR/sketchyvim_enabled"
}

start_svim() {
  command -v svim >/dev/null 2>&1 || {
    printf 'svim is not installed\n' >&2
    return 1
  }

  mark_enabled 1
  if is_running; then
    launchctl kickstart -k "gui/$UID_VALUE/$LABEL" >/dev/null 2>&1 || true
  else
    launchctl bootstrap "gui/$UID_VALUE" "$PLIST" >/dev/null 2>&1 || launchctl kickstart -k "gui/$UID_VALUE/$LABEL" >/dev/null 2>&1 || true
  fi
  sketchybar --trigger sketchyvim_status_changed >/dev/null 2>&1 || true
}

stop_runtime() {
  launchctl bootout "gui/$UID_VALUE/$LABEL" >/dev/null 2>&1 || true
  killall svim >/dev/null 2>&1 || true
  sketchybar --trigger sketchyvim_status_changed >/dev/null 2>&1 || true
}

stop_svim() {
  mark_enabled 0
  stop_runtime
}

apply_preference() {
  if [[ "$(cat "$STATE_DIR/sketchyvim_enabled" 2>/dev/null || printf '0')" == "1" ]]; then
    start_svim
  else
    stop_svim
  fi
}

case "$ACTION" in
  on|start|enable)
    start_svim
    ;;
  off|stop|disable)
    stop_svim
    ;;
  suspend)
    stop_runtime
    ;;
  toggle)
    if is_running; then
      stop_svim
    else
      start_svim
    fi
    ;;
  apply)
    apply_preference
    ;;
  status)
    if is_running; then
      printf 'on\n'
    else
      printf 'off\n'
    fi
    ;;
  *)
    printf 'Usage: %s on|off|toggle|apply|suspend|status\n' "${0##*/}" >&2
    exit 2
    ;;
esac
