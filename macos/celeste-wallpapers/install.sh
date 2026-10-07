#!/bin/zsh
set -euo pipefail

[[ "$(uname -s)" == "Darwin" ]] || { print -u2 "Celeste Wallpapers requires macOS."; exit 1; }

source_root=${0:A:h}
install_root="$HOME/.config/celeste-wallpapers"
state_root="$install_root/state"
lock_path="$state_root/app.lock"
label="com.kianconti.CelesteWallpapers"
launch_agents="$HOME/Library/LaunchAgents"
launch_agent="$launch_agents/$label.plist"
executable="$install_root/Celeste Wallpapers.app/Contents/MacOS/CelesteWallpapers"

lock_is_free() {
  [[ ! -e "$lock_path" ]] && return 0
  /usr/bin/python3 - "$lock_path" <<'PY'
import fcntl
import os
import sys

descriptor = os.open(sys.argv[1], os.O_RDWR)
try:
    fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
except BlockingIOError:
    os.close(descriptor)
    raise SystemExit(1)
fcntl.flock(descriptor, fcntl.LOCK_UN)
os.close(descriptor)
PY
}

if ! lock_is_free; then
  quit_executable="$executable"
  [[ -x "$quit_executable" ]] || quit_executable="$source_root/Celeste Wallpapers.app/Contents/MacOS/CelesteWallpapers"
  [[ -x "$quit_executable" ]] || {
    print -u2 "Celeste Wallpapers is running, but no command executable is available. Quit and restore from its menu first."
    exit 1
  }
  print "Requesting Quit and Restore from running Celeste Wallpapers…"
  "$quit_executable" --quit
  for _ in {1..40}; do
    lock_is_free && break
    sleep 0.25
  done
  lock_is_free || {
    print -u2 "Celeste Wallpapers did not quit. Recovery may still need attention; existing source was not replaced."
    exit 1
  }
fi

if [[ -e "$state_root/slideshow-active" || -e "$state_root/cursor-active" ]]; then
  print -u2 "Recovery markers remain. Restore native wallpaper and cursors before installing; existing source was not replaced."
  exit 1
fi

staging_parent=$(mktemp -d "${TMPDIR:-/tmp}/celeste-wallpapers-install.XXXXXX")
staging="$staging_parent/celeste-wallpapers"
backup=""
mutations_started=0
committed=0
was_loaded=0
plist_temp=""
managed_items=(CelesteWallpapers.swift WallpaperFade.swift CelesteFocusFilter.swift build.sh install.sh README.md .gitignore cursors vendor 'Celeste Wallpapers.app')

cleanup() {
  exit_status=$?
  trap - EXIT
  set +e
  if [[ "$mutations_started" -eq 1 && "$committed" -eq 0 ]]; then
    print -u2 "Install failed; restoring previous Celeste Wallpapers files and LaunchAgent."
    launchctl bootout "gui/$UID/$label" >/dev/null 2>&1 || true
    for item in "${managed_items[@]}"; do
      rm -rf -- "$install_root/$item"
      [[ ! -e "$backup/$item" ]] || cp -Rp "$backup/$item" "$install_root/"
    done
    rm -f -- "$launch_agent"
    if [[ -e "$backup/LaunchAgent.plist" ]]; then
      cp -p "$backup/LaunchAgent.plist" "$launch_agent"
      if [[ "$was_loaded" -eq 1 ]]; then
        launchctl bootstrap "gui/$UID" "$launch_agent" ||
          print -u2 "Previous LaunchAgent file was restored but could not be reloaded: $launch_agent"
      fi
    fi
  fi
  [[ -z "$plist_temp" ]] || rm -f -- "$plist_temp"
  rm -rf -- "$staging_parent"
  exit "$exit_status"
}
trap cleanup EXIT
mkdir -p "$staging"

for file in CelesteWallpapers.swift WallpaperFade.swift CelesteFocusFilter.swift build.sh install.sh README.md .gitignore; do
  [[ -e "$source_root/$file" ]] && cp -p "$source_root/$file" "$staging/$file"
done
rsync -a --exclude 'bin/' "$source_root/cursors/" "$staging/cursors/"
rsync -a --exclude 'bin/' "$source_root/vendor/" "$staging/vendor/"

(
  cd "$staging"
  ./vendor/mousecloak/build.sh
  ./cursors/generate.sh
  ./build.sh
)

lock_is_free || {
  print -u2 "Celeste Wallpapers started during the build. Existing source was not replaced."
  exit 1
}
if [[ -e "$state_root/slideshow-active" || -e "$state_root/cursor-active" ]]; then
  print -u2 "Recovery markers appeared during the build. Existing source was not replaced."
  exit 1
fi

mkdir -p "$install_root" "$launch_agents"
mkdir -p "$install_root/backups"
backup=$(mktemp -d "$install_root/backups/install-$(date +%Y%m%d-%H%M%S).XXXXXX")
for item in "${managed_items[@]}"; do
  [[ ! -e "$install_root/$item" ]] || cp -Rp "$install_root/$item" "$backup/"
done
[[ ! -e "$launch_agent" ]] || cp -p "$launch_agent" "$backup/LaunchAgent.plist"
if launchctl print "gui/$UID/$label" >/dev/null 2>&1; then
  was_loaded=1
fi
launchctl bootout "gui/$UID/$label" >/dev/null 2>&1 || true
mutations_started=1

for file in CelesteWallpapers.swift WallpaperFade.swift CelesteFocusFilter.swift build.sh install.sh README.md .gitignore; do
  if [[ -e "$staging/$file" ]]; then
    cp -p "$staging/$file" "$install_root/$file"
  fi
done
rsync -a --delete "$staging/cursors/" "$install_root/cursors/"
rsync -a --delete "$staging/vendor/" "$install_root/vendor/"
if [[ -e "$install_root/Celeste Wallpapers.app" ]]; then
  mv "$install_root/Celeste Wallpapers.app" "$backup/retired.app"
fi
mv "$staging/Celeste Wallpapers.app" "$install_root/Celeste Wallpapers.app"

plist_temp="$launch_agents/.$label.plist.$$"
/usr/bin/python3 - "$plist_temp" "$label" "$executable" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'wb') as output:
    plistlib.dump({'Label': sys.argv[2], 'ProgramArguments': [sys.argv[3]],
                  'RunAtLoad': True, 'KeepAlive': False}, output)
PY
chmod 600 "$plist_temp"
plutil -lint "$plist_temp" >/dev/null
mv -f "$plist_temp" "$launch_agent"

launchctl bootstrap "gui/$UID" "$launch_agent"
committed=1

print "Installed Celeste Wallpapers at $install_root"
print "LaunchAgent: $launch_agent"
