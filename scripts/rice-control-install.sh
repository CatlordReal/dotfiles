#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
SOURCE="$CONFIG_HOME/rice-control/RiceControl.swift"
INFO_PLIST="$CONFIG_HOME/rice-control/Info.plist"
APP="$CONFIG_HOME/rice-control/RiceControl.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
PLIST="$CONFIG_HOME/rice-control/com.kianconti.rice-control.plist"
LABEL="com.kianconti.rice-control"
AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"
SESSION_PLIST="$CONFIG_HOME/ricing/com.kianconti.catppuccin-session.plist"
SESSION_LABEL="com.kianconti.catppuccin-session"
SESSION_AGENT="$HOME/Library/LaunchAgents/$SESSION_LABEL.plist"
UID_VALUE="$(id -u)"

mkdir -p "$MACOS" "$HOME/Library/LaunchAgents"
swiftc -parse-as-library -target arm64-apple-macosx15.0 "$SOURCE" -framework AppKit -o "$MACOS/RiceControl"
cp "$INFO_PLIST" "$CONTENTS/Info.plist"
ln -sf "$PLIST" "$AGENT"
ln -sf "$SESSION_PLIST" "$SESSION_AGENT"
launchctl bootout "gui/$UID_VALUE/$LABEL" >/dev/null 2>&1 || true
launchctl bootout "gui/$UID_VALUE/$SESSION_LABEL" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$UID_VALUE" "$SESSION_AGENT"
launchctl bootstrap "gui/$UID_VALUE" "$AGENT"
launchctl kickstart -k "gui/$UID_VALUE/$SESSION_LABEL"
launchctl kickstart -k "gui/$UID_VALUE/$LABEL"
