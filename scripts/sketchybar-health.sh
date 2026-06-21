#!/usr/bin/env bash
set -Eeuo pipefail

ACTION="${1:-ensure}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
SKETCHYBAR_DIR="$CONFIG_HOME/sketchybar"
SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-/opt/homebrew/bin/sketchybar}"
SKETCHYBAR_PLIST="$SKETCHYBAR_DIR/com.kianconti.sketchybar.plist"
SKETCHYBAR_LABEL="com.kianconti.sketchybar"
SKETCHYBAR_AGENT="$HOME/Library/LaunchAgents/$SKETCHYBAR_LABEL.plist"
UID_VALUE="$(id -u)"

mkdir -p "$HOME/Library/LaunchAgents"

service_loaded() {
  launchctl print "gui/$UID_VALUE/$SKETCHYBAR_LABEL" >/dev/null 2>&1
}

start_daemon() {
  command -v "$SKETCHYBAR_BIN" >/dev/null 2>&1 || return 1
  ln -sf "$SKETCHYBAR_PLIST" "$SKETCHYBAR_AGENT"
  if service_loaded; then
    if ! pgrep -x sketchybar >/dev/null 2>&1; then
      launchctl kickstart -k "gui/$UID_VALUE/$SKETCHYBAR_LABEL" >/dev/null 2>&1 || true
    fi
  else
    launchctl bootstrap "gui/$UID_VALUE" "$SKETCHYBAR_AGENT" >/dev/null 2>&1 || true
    launchctl kickstart -k "gui/$UID_VALUE/$SKETCHYBAR_LABEL" >/dev/null 2>&1 || true
  fi
}

stop_loader() {
  pkill -f "$SKETCHYBAR_DIR/sketchybarrc" >/dev/null 2>&1 || true
}

bar_loaded() {
  "$SKETCHYBAR_BIN" --query bar 2>/dev/null | /usr/bin/python3 -c '
import json
import sys

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)

items = data.get("items") or []
drawing = data.get("drawing")
sys.exit(0 if drawing == "on" and len(items) > 0 else 1)
'
}

start_loader() {
  stop_loader
  (
    cd "$SKETCHYBAR_DIR"
    nohup env CONFIG_DIR="$SKETCHYBAR_DIR" "$SKETCHYBAR_DIR/sketchybarrc" \
      >/tmp/sketchybarrc.out.log 2>/tmp/sketchybarrc.err.log &
  )
}

ensure_bar() {
  start_daemon
  sleep 0.4
  if ! bar_loaded; then
    start_loader
    sleep 1.5
  fi
  bar_loaded
}

restart_bar() {
  launchctl bootout "gui/$UID_VALUE/$SKETCHYBAR_LABEL" >/dev/null 2>&1 || true
  launchctl bootout "gui/$UID_VALUE" "$SKETCHYBAR_AGENT" >/dev/null 2>&1 || true
  stop_loader
  killall sketchybar cpu_load network_load >/dev/null 2>&1 || true
  start_daemon
  start_loader
  sleep 1.5
  bar_loaded
}

case "$ACTION" in
  ensure)
    ensure_bar
    ;;
  restart)
    restart_bar
    ;;
  status)
    if bar_loaded; then
      printf 'loaded\n'
    else
      printf 'empty\n'
      exit 1
    fi
    ;;
  *)
    printf 'Usage: %s ensure|restart|status\n' "${0##*/}" >&2
    exit 2
    ;;
esac
