# Vendored mousecloak

Personal-use source snapshot from `seanjseymour/Mousecape`, commit
`5834789b1e13a7658cf13895daab9ff98d59f09e` (upstream PR #308).
Original license and README are retained beside this file.

Local patch adds `--check-readback`, a read-only compatibility check for the
`ArrowS` and `IBeamS` cursor names used by macOS 27. It calls only
`CGSCopyRegisteredCursorImages`; it never registers, removes, applies, resets,
or persists cursors. Upstream `--probe` is intentionally not used by automated
checks because it temporarily registers test cursors before restoring them.

Build:

```sh
./build.sh
```

The build produces an ad-hoc-signed Apple Silicon executable at
`bin/mousecloak`. It uses the active macOS SDK, a temporary module cache, and
does not require Xcode's GUI build system.

Safe inspection commands:

```sh
bin/mousecloak --help
bin/mousecloak --check-readback
bin/mousecloak --verify /absolute/path/reference.cape
```

Crash-safe Celeste-mode commands:

```sh
bin/mousecloak --prepare /absolute/path/Celeste.cape \
  --prepared /absolute/private/prepared.cape \
  --prior /absolute/private/prior.cape
bin/mousecloak --apply-session /absolute/private/prepared.cape \
  --expect /absolute/private/prior.cape
bin/mousecloak --verify /absolute/private/prepared.cape
bin/mousecloak --restore-session /absolute/private/prior.cape
bin/mousecloak --verify /absolute/private/prior.cape
```

`--prepare` changes no cursor state. It intersects target keys with current
readable registrations, excludes legacy `Arrow` and `IBeam` on macOS 27, and
requires effective `ArrowS` and `IBeamS`. It also excludes target or baseline
roles above Mousecape's reliable 24-frame registration limit and always excludes
`com.apple.coregraphics.Wait`, including when a legacy/custom Wait currently
reports fewer frames. Apple's non-round-trippable 30-frame Wait baseline
therefore remains native, while separate `com.apple.cursor.4` stays eligible
when readable and within the limit.
Unsupported roles remain native. It writes target and exact prior capes with
identical key sets, using paired same-directory temporary files, atomic renames,
post-serialization parsing, no-overwrite checks, and mode 0600.

`--apply-session` changes global cursor registrations but never changes
Mousecape preferences, backups, or cursor roles absent from prepared cape. It
requires target and `--expect` capes to have the same key set, prevalidates all
current and target data, then exact-verifies `--expect` immediately before its
first registration. A stale prior therefore fails before mutation. It requires
every registration to report applied and verifies every target key afterward.

`--restore-session` validates and reapplies only explicit keys from the saved
prior cape. It deliberately does not require the current registrations to be
readable, so recovery remains possible after an interrupted or partial apply;
one failed registration does not prevent later saved roles from being attempted,
and it verifies every saved key afterward. If every saved key already matches,
as expected after logout/login restores native cursors, it returns success
without registering anything. After any best-effort registrations, full exact
verification decides success; a refused role does not force failure when its
saved native state already matches. `--verify` compares ordered resolution
representations, geometry, hotspots, frame count, frame duration, dimensions,
and normalized pixels. Validation caps cursor/image counts, logical and pixel
dimensions, encoded data, and decoded pixels; animation frames must be stacked
vertically per representation. Frame count is limited to 1...256;
representation count is independent of frame count, matching the private API's
multi-resolution encoding. Any mismatch returns nonzero.

Legacy `--dump` temporarily hides/resizes/selects cursors. Legacy `--apply` and
`--reset` update Mousecape preferences. Do not use those commands for Celeste
mode. `--probe` also temporarily registers test images; it is not read-only.

Run `--prepare` only when no active-mode marker exists; it refuses to overwrite
either output. Create marker only after both outputs succeed. Restore and verify
prior cape before removing marker or recovery files. Caller should use a
private directory and `umask 077`; helper enforces mode 0600.
