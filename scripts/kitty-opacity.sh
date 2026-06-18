#!/usr/bin/env bash
set -Eeuo pipefail

KITTY_CONFIG="${KITTY_CONFIG:-$HOME/.config/kitty/kitty.conf}"

usage() {
  printf 'Usage: %s [opacity]\n' "${0##*/}"
  printf 'Examples: %s 70 | %s 70%% | %s 0.70\n' "${0##*/}" "${0##*/}" "${0##*/}"
}

normalize_opacity() {
  local raw="${1:-70}"
  awk -v raw="$raw" '
    BEGIN {
      gsub(/[[:space:]]/, "", raw)
      if (raw == "") raw = "70"
      had_percent = raw ~ /%$/
      sub(/%$/, "", raw)
      value = raw + 0
      if (value <= 0) value = 70
      ratio = (had_percent || value > 1) ? value / 100 : value
      if (ratio < 0.05) ratio = 0.05
      if (ratio > 1) ratio = 1
      printf "%.2f\n", ratio
    }
  '
}

write_config_opacity() {
  local value="$1"
  local tmp

  [[ -f "$KITTY_CONFIG" ]] || {
    printf 'kitty config not found: %s\n' "$KITTY_CONFIG" >&2
    return 1
  }

  tmp="$(mktemp "${TMPDIR:-/tmp}/kitty.conf.XXXXXX")"
  awk -v value="$value" '
    BEGIN { done = 0 }
    /^[[:space:]]*#?[[:space:]]*background_opacity[[:space:]]+/ {
      if (!done) {
        print "background_opacity " value
        done = 1
      }
      next
    }
    { print }
    END {
      if (!done) print "background_opacity " value
    }
  ' "$KITTY_CONFIG" > "$tmp"
  mv "$tmp" "$KITTY_CONFIG"
}

reload_live_kitty() {
  local value="$1"

  command -v kitty >/dev/null 2>&1 || return 0
  kitty @ set-background-opacity --all "$value" >/dev/null 2>&1 && return 0
  kitty @ load-config "$KITTY_CONFIG" >/dev/null 2>&1 || true
}

main() {
  case "${1:-}" in
    -h|--help)
      usage
      return 0
      ;;
  esac

  local opacity
  opacity="$(normalize_opacity "${1:-70}")"
  write_config_opacity "$opacity"
  reload_live_kitty "$opacity"
  printf '%s\n' "$opacity"
}

main "$@"
