#!/usr/bin/env bash
set -Eeuo pipefail

sketchybar --set "$NAME" label="$(date '+%a %d %b  %H:%M')"
