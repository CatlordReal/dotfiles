#!/bin/zsh
set -euo pipefail

root=${0:A:h}
source_root="$root/src"
output="$root/bin/mousecloak"
sdk=$(xcrun --sdk macosx --show-sdk-path)
module_cache=$(mktemp -d "${TMPDIR:-/tmp}/celeste-mousecloak-modules.XXXXXX")
trap 'rm -rf "$module_cache"' EXIT

mkdir -p "$root/bin"

/usr/bin/clang \
  -arch arm64 \
  -mmacosx-version-min=12.0 \
  -O2 \
  -fblocks \
  -fobjc-exceptions \
  -fobjc-weak \
  -include "$source_root/mousecloak-Prefix.pch" \
  -I"$source_root" \
  -I"$source_root/CGSInternal" \
  -I"$source_root/vendor" \
  -fmodules \
  -fmodules-cache-path="$module_cache" \
  -isysroot "$sdk" \
  "$source_root"/{main,backup,listen,MCPrefs,scale,restore,apply,MCDefs,create,NSBitmapImageRep+ColorSpace}.m \
  "$source_root/vendor/GBCli"/{GBSettings,GBOptionsHelper,GBCommandLineParser}.m \
  -framework Cocoa \
  -framework ApplicationServices \
  -framework SystemConfiguration \
  -o "$output"

/usr/bin/codesign --force --sign - "$output"
/usr/bin/file "$output"
/usr/bin/codesign --verify --strict "$output"
