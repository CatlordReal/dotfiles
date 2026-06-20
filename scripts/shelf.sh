#!/usr/bin/env bash
set -Eeuo pipefail

ACTION="${1:-list}"
TARGET="${2:-}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
SHELF_DIR="${RICING_SHELF_DIR:-$CONFIG_HOME/ricing/shelf}"

mkdir -p "$SHELF_DIR"

list_items() {
  local count shown=0
  count="$(find "$SHELF_DIR" -mindepth 1 -maxdepth 1 ! -name '.DS_Store' 2>/dev/null | wc -l | tr -d ' ')"
  printf '%s\n' "${count:-0}"
  find "$SHELF_DIR" -mindepth 1 -maxdepth 1 ! -name '.DS_Store' -print0 2>/dev/null |
    sort -z |
    while IFS= read -r -d '' path; do
      (( shown >= 5 )) && break
      printf '%s|%s\n' "$(basename "$path")" "$path"
      shown=$((shown + 1))
    done
}

case "$ACTION" in
  open)
    open "$SHELF_DIR"
    ;;
  reveal)
    if [[ -n "$TARGET" && -e "$TARGET" ]]; then
      open -R "$TARGET"
    else
      open "$SHELF_DIR"
    fi
    ;;
  list|status)
    list_items
    ;;
  path)
    printf '%s\n' "$SHELF_DIR"
    ;;
  *)
    printf 'Usage: %s open|reveal <path>|list|path\n' "${0##*/}" >&2
    exit 2
    ;;
esac
