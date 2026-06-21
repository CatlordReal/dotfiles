#!/usr/bin/env bash
set -Eeuo pipefail

ACTION="${1:-status}"
VALUE="${2:-}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_DIR="$CONFIG_HOME/ricing"
THEME_FILE="$STATE_DIR/theme"
SESSION_STATE="$STATE_DIR/session_enabled"
AUTO_FILE="$STATE_DIR/auto_appearance_enabled"
JANKYBORDERS_STATE="$STATE_DIR/jankyborders_enabled"
KITTY_CONFIG="$CONFIG_HOME/kitty/kitty.conf"
SESSION_SCRIPT="$CONFIG_HOME/scripts/catppuccin-session.sh"
TILING_SCRIPT="$CONFIG_HOME/scripts/catppuccin-tiling-mode.sh"
KITTY_OPACITY_SCRIPT="$CONFIG_HOME/scripts/kitty-opacity.sh"
SOUND_SCRIPT="$CONFIG_HOME/scripts/aesthetic-sound.sh"
JANKYBORDERS_SCRIPT="$CONFIG_HOME/scripts/jankyborders.sh"
SKETCHYVIM_SCRIPT="$CONFIG_HOME/scripts/sketchyvim-toggle.sh"
SKETCHYBAR_HEALTH_SCRIPT="$CONFIG_HOME/scripts/sketchybar-health.sh"
SKETCHYBAR_PLIST="$CONFIG_HOME/sketchybar/com.kianconti.sketchybar.plist"
SKETCHYBAR_LABEL="com.kianconti.sketchybar"
SKETCHYBAR_AGENT="$HOME/Library/LaunchAgents/$SKETCHYBAR_LABEL.plist"
UID_VALUE="$(id -u)"

mkdir -p "$STATE_DIR"

normalise_flavour() {
  local value
  value="$(printf '%s' "${1:-mocha}" | tr '[:upper:]' '[:lower:]')"
  case "$value" in
    latte|frappe|macchiato|mocha) printf '%s\n' "$value" ;;
    catppuccin-latte) printf 'latte\n' ;;
    catppuccin-frappe) printf 'frappe\n' ;;
    catppuccin-macchiato) printf 'macchiato\n' ;;
    catppuccin-mocha) printf 'mocha\n' ;;
    *) printf 'mocha\n' ;;
  esac
}

current_theme() {
  normalise_flavour "$(cat "$THEME_FILE" 2>/dev/null || printf 'mocha')"
}

current_opacity() {
  awk '
    /^[[:space:]]*background_opacity[[:space:]]+/ { print $2; found = 1; exit }
    END { if (!found) print "1.00" }
  ' "$KITTY_CONFIG" 2>/dev/null
}

auto_enabled() {
  [[ "$(cat "$AUTO_FILE" 2>/dev/null || printf '1')" == "1" ]]
}

session_enabled() {
  [[ "$(cat "$SESSION_STATE" 2>/dev/null || printf '0')" == "1" ]]
}

borders_enabled() {
  [[ "$(cat "$JANKYBORDERS_STATE" 2>/dev/null || printf '0')" == "1" ]]
}

macos_theme() {
  if [[ "$(defaults read -g AppleInterfaceStyle 2>/dev/null || true)" == "Dark" ]]; then
    printf 'mocha\n'
  else
    printf 'latte\n'
  fi
}

trigger_status() {
  command -v sketchybar >/dev/null 2>&1 || return 0
  sketchybar --trigger appearance_status_changed >/dev/null 2>&1 || true
}

reload_sketchybar() {
  command -v sketchybar >/dev/null 2>&1 || return 0
  "$SKETCHYBAR_HEALTH_SCRIPT" ensure >/dev/null 2>&1 || true
}

apply_theme() {
  local flavour
  flavour="$(normalise_flavour "$1")"
  if session_enabled; then
    "$SESSION_SCRIPT" on "$flavour" >/dev/null 2>&1 || true
  else
    "$TILING_SCRIPT" colors "$flavour" >/dev/null 2>&1 || true
    printf '%s\n' "$flavour" > "$THEME_FILE"
  fi
  trigger_status
}

set_opacity() {
  "$KITTY_OPACITY_SCRIPT" "$1" >/dev/null 2>&1 || true
  "$SOUND_SCRIPT" play toggle >/dev/null 2>&1 || true
  trigger_status
}

set_auto() {
  printf '%s\n' "$1" > "$AUTO_FILE"
  "$SOUND_SCRIPT" play toggle >/dev/null 2>&1 || true
  trigger_status
}

auto_sync() {
  auto_enabled || return 0
  session_enabled || return 0
  local target current
  target="$(macos_theme)"
  current="$(current_theme)"
  [[ "$target" == "$current" ]] && return 0
  CATPPUCCIN_AUTO_SYNC=1 "$SESSION_SCRIPT" on "$target" >/dev/null 2>&1 || true
  trigger_status
}

case "$ACTION" in
  status)
    printf 'theme=%s\n' "$(current_theme)"
    printf 'opacity=%s\n' "$(current_opacity)"
    printf 'auto=%s\n' "$(auto_enabled && printf on || printf off)"
    printf 'sounds=%s\n' "$("$SOUND_SCRIPT" status 2>/dev/null || printf on)"
    printf 'session=%s\n' "$(session_enabled && printf on || printf off)"
    ;;
  theme)
    apply_theme "$VALUE"
    ;;
  opacity)
    set_opacity "${VALUE:-70}"
    ;;
  toggle-auto)
    if auto_enabled; then set_auto 0; else set_auto 1; fi
    ;;
  auto-sync)
    auto_sync
    ;;
  toggle-sounds)
    "$SOUND_SCRIPT" toggle >/dev/null 2>&1 || true
    trigger_status
    ;;
  reload)
    "$0" reload-all
    ;;
  reload-all)
    aerospace reload-config >/dev/null 2>&1 || true
    CATPPUCCIN_KEEP_AUTO=1 "$TILING_SCRIPT" colors "$(current_theme)" >/dev/null 2>&1 || true
    if borders_enabled; then
      "$JANKYBORDERS_SCRIPT" apply "$(current_theme)" >/dev/null 2>&1 || true
    else
      "$JANKYBORDERS_SCRIPT" suspend >/dev/null 2>&1 || true
    fi
    "$SKETCHYVIM_SCRIPT" apply >/dev/null 2>&1 || true
    reload_sketchybar
    "$SOUND_SCRIPT" play reload >/dev/null 2>&1 || true
    trigger_status
    ;;
  toggle-session)
    "$SESSION_SCRIPT" toggle "$(current_theme)" >/dev/null 2>&1 || true
    "$SOUND_SCRIPT" play toggle >/dev/null 2>&1 || true
    trigger_status
    ;;
  *)
    printf 'Usage: %s status|theme <flavour>|opacity <percent>|toggle-auto|auto-sync|toggle-sounds|toggle-session|reload|reload-all\n' "${0##*/}" >&2
    exit 2
    ;;
esac
