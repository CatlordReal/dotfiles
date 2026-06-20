#!/usr/bin/env bash
set -Eeuo pipefail

ACTION="${1:-play}"
KIND="${2:-theme}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_DIR="$CONFIG_HOME/ricing"
PREF="$STATE_DIR/sounds_enabled"

mkdir -p "$STATE_DIR"

is_enabled() {
  [[ "$(cat "$PREF" 2>/dev/null || printf '1')" == "1" ]]
}

set_enabled() {
  printf '%s\n' "$1" > "$PREF"
}

sound_file() {
  case "$KIND" in
    reload) printf '/System/Library/Sounds/Pop.aiff\n' ;;
    toggle) printf '/System/Library/Sounds/Tink.aiff\n' ;;
    *) printf '/System/Library/Sounds/Glass.aiff\n' ;;
  esac
}

play_sound() {
  is_enabled || return 0
  local file
  file="$(sound_file)"
  [[ -f "$file" ]] || return 0
  command -v afplay >/dev/null 2>&1 || return 0
  afplay -v 0.045 "$file" >/dev/null 2>&1 &
}

case "$ACTION" in
  play)
    play_sound
    ;;
  on|enable)
    set_enabled 1
    ;;
  off|disable)
    set_enabled 0
    ;;
  toggle)
    if is_enabled; then
      set_enabled 0
    else
      set_enabled 1
      play_sound toggle
    fi
    ;;
  status)
    if is_enabled; then printf 'on\n'; else printf 'off\n'; fi
    ;;
  *)
    printf 'Usage: %s play [theme|reload|toggle]|on|off|toggle|status\n' "${0##*/}" >&2
    exit 2
    ;;
esac
