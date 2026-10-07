# Local changes

Upstream source is pinned in `UPSTREAM_COMMIT`.

- Build `mousecloak` directly with Command Line Tools for Apple Silicon.
- Add read-only `--check-readback` for legacy and macOS 27 cursor names.
- Add read-only `--prepare <target> --prepared <target-output> --prior
  <recovery-output>`. It includes only target keys with readable current
  registrations, excludes legacy Arrow/IBeam, requires ArrowS/IBeamS, excludes
  any target or captured baseline role above Mousecape's reliable 24-frame
  registration limit, and atomically writes mode-0600 capes with identical key
  sets. This leaves Apple's 30-frame `com.apple.coregraphics.Wait` unchanged;
  `CGSRegisterCursorWithImages` returns `CGError 1000` when asked to restore its
  dumped representation. Independently registered `com.apple.cursor.4` remains
  eligible when its target and baseline are within the limit.
- Add read-only `--verify <cape>` for every included cursor: ordered image
  representations, geometry, hotspots, frame count/duration, dimensions, and
  normalized pixels.
- Add narrow `--apply-session <prepared-cape> --expect <prior-cape>` without
  global reset, stale backup changes, or Mousecape preference writes. Target and
  expected capes must have identical key sets. It prevalidates all current and
  target cursor data, exact-verifies expected state immediately before the first
  mutation, applies only explicit prepared keys, rejects ignored registrations,
  then verifies all keys.
- Add `--restore-session <prior-cape>` for interrupted/partial recovery. It
  validates every saved key, does not require current registrations to be
  readable, reapplies every explicit key even when one registration fails, and
  verifies the full saved cape. When every key already matches, such as after a
  logout/login restores Apple's native cursors, it succeeds without registering
  anything; this lets callers safely clear retained recovery state even when the
  cape contains Apple's non-round-trippable 30-frame Wait snapshot. After a
  best-effort attempt, full exact verification is authoritative: refused
  registrations do not force failure when every saved role now matches.
- Validate finite numeric fields, positive bounded logical/image dimensions,
  in-bounds hotspots, 1...256 frames, nonnegative duration, encoded/decoded
  memory limits, and vertically stacked frames in each resolution. Resolution
  representation count is independent of frame count.
- Retain `--dump-safe` as a read-only diagnostic snapshot; Celeste mode uses
  paired `--prepare` output instead.
- Return nonzero for apply, snapshot, verification, readback, and core-reset
  failures.

No helper/login item, daemon, SIP change, system-file edit, or automatic apply
is included.
