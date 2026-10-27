---
name: flipper-apps
description: Build, review, test, package, or release Flipper Zero applications against an actual pinned firmware source tree, with native UI, bounded RAM, artifact checks, and honest hardware proof.
---

# Flipper application workflow

Read `${CODEX_HOME:-$HOME/.codex}/AGENTS.md`, the repository's `AGENTS.md`, and applicable skills before work. This skill supplements those instructions and does not grant publishing, device-write, credential-recovery, or other external authorization.

## Start from the product workflow

Identify the user's real card, reader, or device workflow before choosing screens or APIs. Keep the application focused on user actions and results. Do not expose development tests, runtime test assets, internal diagnostics, implementation notes, or permanent hint footers as product navigation unless the user asks for them.

Use concise native Flipper UI patterns and reuse firmware widgets, dialogs, file browsers, notifications, and protocol helpers where they fit. On the 128x64 display, preserve deliberate spacing: use a 10-pixel line step for ordinary text when a 9-pixel step causes glyph collisions. Check long labels, scrolling, cancellation, busy states, empty states, and Back-button behavior in the real renderer.

Put the primary workflow first and About last when present. Group related secondary tools under clear submenus. Implement real steps with actions and integrated outcomes; put save/export at completion rather than in unrelated global menus. Offer file selection where a step needs it, and keep logs reachable while an operation runs. Wrap menu navigation from first to last and last to first. Use appropriate existing firmware status graphics during waiting/scanning; keep necessary status text readable and minimize scrolling in the main workflow.

Use native button bars and directional/OK glyphs for context actions. Hide controls that cannot help the current step; do not leave invisible actions responding to input. Keep Back consistent across nested menus, modal pickers, confirmations, live logs, cancellation, results, and resumed workflows. A live log should return to its running operation; cancellation drains before returning to the operation's caller.

For short success/failure feedback, prefer firmware notifications so mute, vibration and stealth settings remain authoritative. Signal an evidenced result once; retries, passive observations and user cancellation should not imply success. Keep capture readiness, durable saving and completed external operations separate.

Use Dolphin deeds only when an activity has a fitting native deed. Award attempt, actual success, and first save appropriately; avoid XP for passive monitoring, simulated results, browsing, or repeatedly saving the same result.

Every delivered FAP needs a custom launcher icon. Wire the source asset into `application.fam`, check the embedded bytes in the built artifact, and include the source icon with release material.

## Use actual firmware APIs

Inspect the pinned firmware source and exported API table before designing an integration. Match the installed firmware version when it is known. Do not assume upstream Flipper or another Momentum revision has the same ABI, protocol behavior, data layout, or exports. Keep firmware checkouts as read-only dependencies unless the user explicitly requests firmware work.

Prefer native protocol dictionaries, scanners, pollers, listeners, storage formats, and application handoffs over duplicated algorithms when those APIs match the product and verified source revision. Do not turn one project's native-API choices into universal Flipper architecture. Release radio resources before handing off to another application. Treat a launched tool as a pending external step; never infer that it completed successfully.

## Budget constrained resources

Measure sizes with the target ARM build. Host `sizeof`, enum width, allocator behavior, and stack results are not target proof. Momentum builds may use `-fshort-enums`; account for that before interpreting structures or persistent layouts.

Budget each operation from actual target types and native allocation behavior. Include simultaneous old/new buffers during growth, parser temporaries, protocol state, thread stacks, queues, strings, and allocator overhead. Stage large operations so mutually exclusive engines and decoded objects do not coexist. A smaller free-heap guard does not prove a larger allocation is safe. Check total free heap and largest contiguous block where the firmware exports both.

When offline tools threaten active-operation RAM, first reclaim lazy detail buffers and mutually exclusive objects. A native embedded plugin can stage genuinely offline code outside radio operation; validate its descriptor, imports, measured load/working budgets and extraction, release all mappings before RF, and keep delivery self-contained. Do not introduce a plugin solely to rearrange code.

Callbacks copy bounded data only. Keep storage, UI work, stop/join, and deallocation on the owning worker. Cancellation must stop new work, drain native operations, then release resources; describe any native call that can delay cancellation.

## Verify in layers

Run focused host tests, sanitizers where supported, the native ARM build with warnings as errors, SDK import validation, launcher-icon validation, and packaging checks. Inspect renderer captures when UI changed, but label host-rendered frames as simulations.

Review critical subsystems independently when requested or warranted. Give reviewers bounded areas (UI, navigation, radio ownership/evidence, storage, feedback), then run a separate integration pass. Fix actionable findings, rerun affected checks and re-review corrections; stop only when no actionable findings remain, with hardware gaps explicit.

Keep proof tiers separate:

- Host tests prove portable logic under host layouts.
- Native compilation and APPCHK prove target compilation, metadata, and enabled imports.
- Artifact inspection proves packaged contents and embedded icon data.
- Only a physical device proves RF behavior, on-device RAM headroom, storage timing, display interaction, native handoffs, and reader/card compatibility.

Do not convert a host-only discrepancy into a firmware bug claim. First reproduce it against actual target flags, types, code paths, and source revision.

## Package and publish narrowly

Make the standalone `.fap` the primary release asset unless the user requests another installation format. Optional installer ZIPs should contain only installation material needed by users. Keep source, tests, internal captures, firmware trees, backups, caches, private card data, nonce logs, dictionaries, and unrelated third-party applications out of installer bundles. Retain third-party notices only for code or assets actually redistributed.

Keep the README short: install, start, core workflow, safety/proof limits, build commands, source pin. Public repository publishing, releases, tags, uploads, and overwrites require explicit authorization for that action; authorization recorded for one project or date does not grant it for future work.

## Project-specific references

For NFC Diagnostic Suite work, read [references/nfc-suite-requirements.md](references/nfc-suite-requirements.md). Its authorization and source-version notes are scoped to that project and recorded date.
