#!/bin/zsh
set -euo pipefail
cd -- "${0:A:h}"
app="$PWD/Celeste Wallpapers.app"
developer_dir="${DEVELOPER_DIR:-$(xcode-select -p)}"
if ! DEVELOPER_DIR="$developer_dir" xcrun --find appintentsmetadataprocessor >/dev/null 2>&1; then
    for candidate in /Applications/Xcode.app/Contents/Developer /Applications/Xcode-beta.app/Contents/Developer; do
        if DEVELOPER_DIR="$candidate" xcrun --find appintentsmetadataprocessor >/dev/null 2>&1; then developer_dir="$candidate"; break; fi
    done
fi
processor="$(DEVELOPER_DIR="$developer_dir" xcrun --find appintentsmetadataprocessor)"
[[ -x "$processor" ]] || { print -u2 "Full Xcode required for Focus Filter metadata."; exit 1; }
mousecloak="$PWD/vendor/mousecloak/bin/mousecloak"
[[ -x "$mousecloak" ]] || { print -u2 "Required helper missing: $mousecloak"; exit 1; }
# Prefer the user's existing signing identity so Desktop access survives rebuilds.
signing_identity="$(security find-identity -v -p codesigning 2>/dev/null | awk '/[0-9]+\) / { print $2; exit }')"
[[ -n "$signing_identity" ]] || signing_identity="-"
staging="$(mktemp -d /private/tmp/celeste-build.XXXXXX)/Celeste Wallpapers.app"
trap 'rm -rf -- "${staging:h}"' EXIT
mkdir -p "$staging/Contents/MacOS" "$staging/Contents/Resources"
build_root="${staging:h}"
sdk="$(DEVELOPER_DIR="$developer_dir" xcrun --sdk macosx --show-sdk-path)"
xcode_build="$(DEVELOPER_DIR="$developer_dir" xcodebuild -version | awk '/Build version/ { print $3; exit }')"
target="$(uname -m)-apple-macosx13.0"
module_cache="$build_root/module-cache"
const_values="$build_root/CelesteFocusFilter.swiftconstvalues"
protocols="$build_root/app-intent-protocols.json"
source_list="$build_root/app-intent-sources.list"
const_values_list="$build_root/app-intent-const-values.list"

cat > "$protocols" <<'JSON'
["AnyResolverProviding","AppEntity","AppEnum","AppExtension","AppIntent","AppIntentsPackage","AppShortcutProviding","AppShortcutsProvider","AppUnionValue","AppUnionValueCasesProviding","DynamicOptionsProvider","EntityQuery","ExtensionPointDefining","IntentValueQuery","Resolver","TransientEntity","_AssistantIntentsProvider","_GenerativeFunctionExtractable","_IntentValueRepresentable"]
JSON
print -r -- "$PWD/CelesteFocusFilter.swift" > "$source_list"
print -r -- "$const_values" > "$const_values_list"

DEVELOPER_DIR="$developer_dir" xcrun swiftc \
    -parse-as-library -c CelesteFocusFilter.swift \
    -module-name CelesteWallpapers \
    -target "$target" -sdk "$sdk" \
    -module-cache-path "$module_cache" \
    -emit-const-values-path "$const_values" \
    -Xfrontend -const-gather-protocols-file -Xfrontend "$protocols" \
    -o "$build_root/CelesteFocusFilter.o"

cat CelesteWallpapers.swift WallpaperFade.swift CelesteFocusFilter.swift > "$build_root/main.swift"
DEVELOPER_DIR="$developer_dir" xcrun swiftc \
    -O -module-name CelesteWallpapers \
    -target "$target" -sdk "$sdk" \
    -module-cache-path "$module_cache" \
    -framework AppKit -framework AppIntents \
    "$build_root/main.swift" \
    -o "$staging/Contents/MacOS/CelesteWallpapers"

"$processor" \
    --output "$staging/Contents/Resources" \
    --toolchain-dir "$developer_dir/Toolchains/XcodeDefault.xctoolchain" \
    --module-name CelesteWallpapers \
    --sdk-root "$sdk" \
    --xcode-version "$xcode_build" \
    --platform-family macOS \
    --deployment-target 13.0 \
    --target-triple "$target" \
    --source-file-list "$source_list" \
    --swift-const-vals-list "$const_values_list" \
    --no-app-shortcuts-localization \
    --force
metadata="$staging/Contents/Resources/Metadata.appintents/extract.actionsdata"
[[ -s "$metadata" ]] || { print -u2 "App Intents metadata missing: $metadata"; exit 1; }
/usr/bin/grep -q 'CelesteFocusFilter' "$metadata" || { print -u2 "CelesteFocusFilter missing from App Intents metadata"; exit 1; }
cat > "$staging/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.kianconti.CelesteWallpapers</string>
<key>CFBundleName</key><string>Celeste Wallpapers</string>
<key>CFBundleExecutable</key><string>CelesteWallpapers</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSDesktopFolderUsageDescription</key><string>Read the Celeste-Wallpapers folder for your wallpaper slideshow.</string>
</dict></plist>
PLIST
cp "$mousecloak" "$staging/Contents/MacOS/mousecloak"
cp cursors/Celeste.cape "$staging/Contents/Resources/Celeste.cape"
codesign --force --sign "$signing_identity" "$staging/Contents/MacOS/mousecloak"
"$staging/Contents/MacOS/CelesteWallpapers" --self-test
codesign --force --sign "$signing_identity" "$staging"
if [[ -d "$app" ]]; then
    backup="$PWD/backups/$(date +%Y%m%d-%H%M%S).app"
    mkdir -p "${backup:h}"
    mv -- "$app" "$backup"
fi
mv -- "$staging" "$app"
