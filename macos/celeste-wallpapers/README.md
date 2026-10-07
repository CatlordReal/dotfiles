# Celeste Wallpapers

A native macOS menu bar toggle between your current wallpaper configuration and a shuffled slideshow from `~/Desktop/Programming+/Celeste-Wallpapers`, changing every 60 seconds. Celeste mode includes original strawberry pixel cursors using a pinned Mousecape helper.

Left-click toggles. Right-click offers Next Wallpaper, Restore, error details, and Quit and Restore. Wallpaper changes fade for 0.5 seconds; Reduce Motion disables the fade. Background errors never activate the app.

Automatic light/dark appearance and system accent/highlight preferences are preserved. The menu bar icon follows system appearance. Native wallpaper restoration preserves the captured provider configuration, including dynamic wallpaper behavior, while leaving screen saver settings intact.

## Build and run

Requires Apple silicon, macOS, full Xcode (including App Intents metadata tools), and an unlocked graphical session. Command Line Tools alone cannot package the Focus Filter. Global cursor replacement uses private macOS APIs; this implementation was developed on macOS 27 and needs retesting after OS updates.

From the dotfiles checkout, run `./macos/celeste-wallpapers/install.sh` to build, install at `~/.config/celeste-wallpapers`, and start at login. Updates preserve recovery state and back up the previous app/source. The installer refuses updates while recovery is pending.

For a build without installation:

```sh
./vendor/mousecloak/build.sh
./cursors/generate.sh
./build.sh
open -g "Celeste Wallpapers.app"
```

Allow Desktop-folder access when macOS requests it. Keep the app at a stable path. The build prefers an existing local signing identity so rebuilding preserves permission identity; ad-hoc signing is the fallback.

To link your Focus, open System Settings > Focus > Celeste > Add Filter > Celeste Wallpapers. Enable Use Celeste Mode and add it. macOS then starts Celeste mode when that Focus activates and restores your saved wallpaper/cursors when it deactivates. Manual clicks still work; the next Focus change sets the corresponding mode. Background Focus changes do not activate the app.

The wallpaper folder and images are not included in this repository.

## Recovery

State lives in `~/.config/celeste-wallpapers/state`, independently of the source checkout. Never delete this folder while Celeste mode is active or recovery is pending. Use Restore or Quit and Restore before uninstalling. Errors stop the slideshow and retain recovery snapshots for another attempt.

Native wallpaper restoration briefly freezes and restarts the current user's WallpaperAgent to restore its saved desktop configuration. This may flicker. No root helper, SIP changes, or system-file edits are required.

Cursor state is captured before application and verified after restoration. Animations above 24 frames (including the native spinning Wait cursor) remain untouched because macOS rejects exact restoration through Mousecape. Only readable prepared cursor roles are changed; unrelated registrations and Mousecape preferences remain untouched. The helper source, license, pinned upstream commit, and local patch are under `vendor/mousecloak/`.

Builds retain the previous app in `backups/`. Runtime state, backups, binaries, and personal wallpapers must not be committed.
