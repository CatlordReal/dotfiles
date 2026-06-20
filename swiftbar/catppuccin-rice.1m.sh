#!/usr/bin/env bash

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CONTROL="$CONFIG_HOME/scripts/appearance-control.sh"
SESSION="$CONFIG_HOME/scripts/catppuccin-session.sh"

status="$("$CONTROL" status 2>/dev/null || true)"
theme="$(printf '%s\n' "$status" | awk -F= '$1 == "theme" { print $2; exit }')"
session="$(printf '%s\n' "$status" | awk -F= '$1 == "session" { print $2; exit }')"
opacity="$(printf '%s\n' "$status" | awk -F= '$1 == "opacity" { print $2; exit }')"

theme="${theme:-mocha}"
session="${session:-off}"
opacity="${opacity:-1.00}"

if [[ "$session" == "on" ]]; then
  printf '󱓞 %s\n' "$theme"
else
  printf '󱓞 off\n'
fi

printf '%s\n' '---'
printf 'Rice session: %s | color=%s\n' "$session" "$([[ "$session" == on ]] && printf '#a6e3a1' || printf '#f38ba8')"
printf 'Kitty opacity: %s\n' "$opacity"
printf '%s\n' '---'
printf 'Toggle rice | bash=%q param1=toggle terminal=false refresh=true\n' "$SESSION"
printf 'Reload all | bash=%q param1=reload-all terminal=false refresh=true\n' "$CONTROL"
printf '%s\n' '---'
printf 'Mocha | bash=%q param1=theme param2=mocha terminal=false refresh=true\n' "$CONTROL"
printf 'Macchiato | bash=%q param1=theme param2=macchiato terminal=false refresh=true\n' "$CONTROL"
printf 'Frappe | bash=%q param1=theme param2=frappe terminal=false refresh=true\n' "$CONTROL"
printf 'Latte | bash=%q param1=theme param2=latte terminal=false refresh=true\n' "$CONTROL"
printf '%s\n' '---'
printf 'Opacity 60%% | bash=%q param1=opacity param2=60 terminal=false refresh=true\n' "$CONTROL"
printf 'Opacity 70%% | bash=%q param1=opacity param2=70 terminal=false refresh=true\n' "$CONTROL"
printf 'Opacity 85%% | bash=%q param1=opacity param2=85 terminal=false refresh=true\n' "$CONTROL"
printf 'Opacity 100%% | bash=%q param1=opacity param2=100 terminal=false refresh=true\n' "$CONTROL"
printf '%s\n' '---'
printf 'Open config | bash=/usr/bin/open param1=%q terminal=false\n' "$CONFIG_HOME"
