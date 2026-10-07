#!/bin/zsh
set -euo pipefail

root=${0:A:h}
module_cache=$(mktemp -d "${TMPDIR:-/tmp}/celeste-cursor-modules.XXXXXX")
trap 'rm -rf "$module_cache"' EXIT

if [[ -d /Applications/Xcode-beta.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
fi
export CLANG_MODULE_CACHE_PATH="$module_cache"
export SWIFT_MODULECACHE_PATH="$module_cache"

xcrun swift "$root/generate.swift"
