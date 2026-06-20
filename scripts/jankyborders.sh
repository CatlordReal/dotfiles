#!/usr/bin/env bash
set -Eeuo pipefail

ACTION="${1:-apply}"
FLAVOUR="${2:-$(cat "${XDG_CONFIG_HOME:-$HOME/.config}/ricing/theme" 2>/dev/null || printf 'mocha')}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_DIR="$CONFIG_HOME/ricing"
PLIST="$CONFIG_HOME/borders/com.kianconti.borders.plist"
LABEL="com.kianconti.borders"
UID_VALUE="$(id -u)"
BORDER_WIDTH="${JANKYBORDERS_WIDTH:-4.0}"
# Use the native rounded style. This follows the current macOS window corner
# shape exposed by the borders binary rather than hardcoding an old radius.
BORDER_STYLE="${JANKYBORDERS_STYLE:-round}"
BORDER_BLACKLIST="${JANKYBORDERS_BLACKLIST:-Dock,Window Server,Control Center,Notification Center,SystemUIServer,Spotlight,loginwindow}"

mkdir -p "$STATE_DIR" "$CONFIG_HOME/borders"

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

palette() {
  case "$(normalise_flavour "$1")" in
    latte) ACTIVE=8839ef; INACTIVE=bcc0cc ;;
    frappe) ACTIVE=ca9ee6; INACTIVE=51576d ;;
    macchiato) ACTIVE=c6a0f6; INACTIVE=494d64 ;;
    *) ACTIVE=cba6f7; INACTIVE=45475a ;;
  esac
}

apply_borders() {
  command -v borders >/dev/null 2>&1 || {
    printf 'borders is not installed\n' >&2
    return 1
  }

  palette "$FLAVOUR"
  printf '1\n' > "$STATE_DIR/jankyborders_enabled"
  printf '%s\n' "$(normalise_flavour "$FLAVOUR")" > "$STATE_DIR/theme"

  # A clean restart avoids stale border overlays lingering after apps close.
  suspend_borders
  launchctl bootstrap "gui/$UID_VALUE" "$PLIST" >/dev/null 2>&1 || true
  launchctl kickstart -k "gui/$UID_VALUE/$LABEL" >/dev/null 2>&1 || true
}

run_borders() {
  command -v borders >/dev/null 2>&1 || exit 1
  FLAVOUR="$(cat "$STATE_DIR/theme" 2>/dev/null || printf '%s' "$FLAVOUR")"
  palette "$FLAVOUR"
  exec borders \
    style="$BORDER_STYLE" \
    width="$BORDER_WIDTH" \
    hidpi=on \
    blacklist="$BORDER_BLACKLIST" \
    active_color="0xff$ACTIVE" \
    inactive_color="0x88$INACTIVE" \
    background_color="0x00000000"
}

stop_borders() {
  printf '0\n' > "$STATE_DIR/jankyborders_enabled"
  suspend_borders
}

suspend_borders() {
  launchctl bootout "gui/$UID_VALUE/$LABEL" >/dev/null 2>&1 || true
  killall borders >/dev/null 2>&1 || true
}

case "$ACTION" in
  apply|start|on|enable)
    apply_borders
    ;;
  run)
    run_borders
    ;;
  off|stop|disable)
    stop_borders
    ;;
  suspend)
    suspend_borders
    ;;
  toggle)
    if pgrep -x borders >/dev/null 2>&1; then
      stop_borders
    else
      apply_borders
    fi
    ;;
  status)
    if pgrep -x borders >/dev/null 2>&1; then
      printf 'on\n'
    else
      printf 'off\n'
    fi
    ;;
  *)
    printf 'Usage: %s apply|toggle|status|off|suspend [flavour]\n' "${0##*/}" >&2
    exit 2
    ;;
esac
