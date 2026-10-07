# Celeste's Strawberries cursor cape

Exact cursor artwork from [Celeste's Strawberries](https://www.rw-designer.com/cursor-set/celeste), by [Cappuccino093](https://www.rw-designer.com/user/106553), published April 29, 2022 and released by its author to the public domain. Celeste and its artwork belong to their respective creators.

The unmodified downloaded CUR/ANI files live under `source/`; `source/SHA256.json` pins every original file. `generate.py` verifies hashes, decodes 32-bit CUR and ANI containers without image-library resampling, preserves hotspots and uniform ANI timing, emits exact 1x pixels plus nearest-neighbour 2x representations, then writes `Celeste.cape` and previews under `assets/`.

Regenerate:

```sh
./generate.sh
```

Mapped source roles: arrow, I-beam, link, crosshair, busy, unavailable, move, and four resize directions. ANI input is capped at 24 frames for Mousecape compatibility. `com.apple.coregraphics.Wait` remains present in the source cape for diagnostic completeness but the session-preparation helper always excludes it because Apple's native Wait cannot be restored reliably through the private registration API.

Generation does not apply cursors or touch Mousecape preferences.
