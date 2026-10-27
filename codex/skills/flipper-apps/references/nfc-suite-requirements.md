# NFC Diagnostic Suite requirements

These requirements capture the NFC Diagnostic Suite decisions made on 2026-10-15. Apply them only to that project unless the user explicitly adopts them elsewhere. They do not preserve authorization for future public publishing or for testing systems the user does not own or have permission to test.

## Product and source boundary

- Deliver a standalone native Momentum FAP outside the firmware tree. Keep the firmware checkout unchanged and excluded from source and release artifacts.
- Target the installed Momentum tag `mntm-012`, commit `e1784e7418d8b074e971983ceb6fef0f37e52ae4`, API 87.1. Earlier development inspection used commit `d3f89dfe2ef6b01839201598e9be1590cba80322`; required exported APIs and relevant public/native headers were checked against `mntm-012`. Treat this as date-scoped project context and verify the live device/source before future compatibility claims.
- Preserve all diagnostics for 13.56 MHz NFC and 125 kHz LF RFID. No expansion module is required.
- Reuse exported native APIs and saved-file formats. Do not duplicate native writing, key-recovery, cryptographic, or specialized-card algorithms.
- Keep diagnostics read-only. Writing, emulation, key recovery, and specialized-card operations occur only through compatible native tools after the suite releases the radio. Runtime availability controls handoff actions. Launching a tool is not proof of completion.

## User workflow and UI

- Make the main product flow workflow-first: card work and reader work. Card work begins with whether the user has a card. Reader-only work must not invent card data.
- Default identification tries NFC, then LF when no NFC identity appears. Remember the last detected band for repeat tests; use NFC only when no prior band exists.
- Implement card work as a native step-by-step wizard, not a separate Guide block or explanatory detour. Derive each next action from current evidence, protocol support, source completeness, target requirements, and installed-tool availability. Hide irrelevant actions rather than displaying a fixed list.
- Put a file-selection control on each wizard step that requires a source, baseline, or verification target. Do not force users through a separate global browser before continuing the step.
- Show integrated results, then make save/export the final workflow action. Group saved-card and session tools together. Place About last. Keep live log available while an operation is active; do not leave it as a standalone destination that is inaccessible or empty outside active work.
- Do not ship test/demo screens, runtime test assets, developer menus, or a persistent hint footer. Keep copy short and functional. Show Dolphin status or deed outcomes on relevant result or completion screens without turning them into a separate developer view.
- Use native visual conventions. Increase the crowded 9-pixel text baseline step by 1 pixel to 10 pixels, wrap long content, and preserve Up/Down scrolling. Wrap Up on the first menu item to the last, and Down on the last to the first. Verify menus, busy/cancel states, long details, compact results, and final save screens with the production renderer.
- Use a custom suite icon, wire it through `fap_icon`, inspect the built FAP metadata, and ship the source PNG with installation material.

## Evidence model

- Keep scanner candidates, direct command confirmation, saved historical evidence, simulation, inference, and unsupported results distinct.
- A scanner classification alone is not family confirmation. Do not infer a credential, chip authenticity, reader model, RF strength, successful clone, or access-system acceptance from UID, ATQA, SAK, field presence, a saved-file match, or an application launch.
- Preserve volatile-identity limits: ISO A four-byte identifiers beginning with `08` and ISO B PUPIs may change. Retain the selected identity and label reduced cross-activation correlation.
- Validate identity continuity before attaching later direct responses. A manufacturing UID from a version response does not silently replace the selected identity.
- Do not call source behavior a firmware bug from a host assumption. Target builds use ARM layouts and `-fshort-enums`; verify target flags, native data types, and the pinned code path first.

## NFC coverage

Support Momentum's 15 NFC scanner protocols without iterating beyond `NfcProtocolNum`: ISO14443-A, ISO14443-B, ISO14443-4A, ISO14443-4B, ISO15693-3, FeliCa, MIFARE Ultralight/NTAG2xx, MIFARE Classic, MIFARE Plus, MIFARE DESFire, SLIX, ST25TB, NTAG4xx, Type 4 Tag, and EMV.

- ISO14443-A: record selected UID, ATQA, final SAK, and UID-derived cascade count. Do not claim intermediate BCC or cascade SAK values unavailable from the API.
- ISO14443-B: record activation PUPI and its volatility limit.
- ISO14443-4A/4B: distinguish transport activation from higher-family confirmation.
- ISO15693: inventory only in diagnostics; no passwords or writes.
- FeliCa: polling IDm/PMm only; no authenticated service or key extraction.
- Ultralight/NTAG2xx: page-zero read plus `GET_VERSION`; older cards without version support remain generic Type 2 candidates.
- Classic: a valid four-byte AUTH-A block-zero nonce response is a limited family confirmation. It supplies no key and does not complete authentication. Capacity from SAK remains a hint.
- Plus and DESFire: use read-only `GET_VERSION` with family shape and identity checks. Never confirm Plus from a DESFire-shaped response or from SAK/ATQA/ATS alone.
- SLIX: scanner or UID-derived classification remains a candidate unless a direct safe command confirms more.
- ST25TB: initiate, select, and GetUID only.
- NTAG4xx: wrapped `GET_VERSION` with bounded chaining; ISO-DEP WTX can delay drain.
- Type 4 Tag: NDEF application selection only; no diagnostic payload extraction claim.
- EMV: PPSE directory selection only; no payment credential extraction.
- PicoPass is outside the 15-protocol NFC scanner. Any compatible-tool handoff is optional and does not claim suite detection or confirmation.

Use independent direct probes to upgrade scanner candidates to command-confirmed evidence where supported. The scanner's byte-count copy is correct for its byte-sized result entries; do not describe it as a filter defect. Keep deadlines explicit, but label them as application wait bounds when synchronous native calls or WTX can outlive them.

## LF coverage

- Use Momentum's registered LF protocol dictionary and automatic ASK/PSK decoder. Preserve the exact native protocol name and up to 32 decoded bytes.
- Confirm LF identity only after the native decoder reports a complete read. Field presence alone is not decoded-card evidence.
- Reader observation may report sampled field presence and the firmware-provided frequency counter conversion. It is not waveform capture, calibrated RF metrology, range, protocol decoding, or reader-brand identification.
- Blank compatibility and write support depend on exact protocol, complete source data, and target. Do not generalize from the dictionary's encoder support.

## Reader and owned-system workflow

- Scope card, reader, writing, and recovery guidance to systems the user owns or is authorized to test. This project-specific consent does not authorize future unrelated targets.
- Offer passive NFC/LF field observation, a clearly synthetic Type A probe, and Classic listener collection. Synthetic listener identities remain private configuration and never become observed identity evidence.
- Classic recovery evidence requires complete matching native authentication contexts: same CUID, sector, and key type with two distinct complete Nt/Nr/Ar triples. Shared components can be valid; reject only identical full replay triples and exact duplicate pairs.
- Append deduplicated records in Momentum's native `.mfkey32.log` format only after stopping the listener and releasing the radio. Preserve existing content, cap scans, report incomplete tails and storage errors, and never display keys.
- Recovery success, writing success, and reader acceptance remain external results. Resume the saved workflow without marking them complete. Verify a written copy by reading it into a different saved file and comparing validated data, while still stating the physical acceptance limit.

## Files, sessions, reports, and trust boundaries

- Treat `.nfc` and `.rfid` files as untrusted. Perform bounded streaming preflight before native decoders. Cap file/line/string/count/allocation sizes, reject duplicate critical fields, validate mandatory order where native loaders reuse temporaries, and compare native decoded identity against preflight results.
- Guard known target-loader hazards at the trust boundary, including Classic block representation, Plus ordered security level, DESFire counts and access rights, EMV raw string lengths/order, ISO14443-4 ATS length, FeliCa public-block data, NDEF size, and ISO15693 block products.
- Avoid Momentum's growing `realloc` path at the pinned source because its implementation copies the new size. Allocate a new bounded buffer, copy only initialized bytes, then free the old buffer.
- Before native decoding, check target free heap and largest contiguous block using allocation estimates derived from actual ARM structures and firmware behavior. Stage comparisons to avoid two large native objects where possible.
- Store suite sessions in a versioned, bounded, checksummed format. Preserve legacy version-one decoding and the wider LF identity in version two. Loaded confirmation is historical; preserve original simulation provenance.
- Before export, create and verify each output-directory component; accept `FSE_EXIST` only when the existing entry is a directory. Export timestamped JSON and CSV without overwrite using buffered temporary writes, sync/close checks, and safe publication. Report the failing operation, path, native `FS_Error`, retained temporary file, and any successfully published partial output. Reports may contain identifiers; say so.
- Saved-file equality means decoded saved data match. It does not prove physical identity, complete Classic sectors/keys, cloning success, or reader acceptance.

## Ownership and persistence

- One worker owns each radio engine and all native allocate/start/stop/join/free calls. Callbacks copy bounded events only. UI and storage work occur outside callbacks.
- Persist workflow state with explicit fields, strict tokens, size bounds, validation, temporary publication, backup fallback, and prior-state preservation. A pending handoff records intent only.
- Keep the card-workflow identity separate from later standalone scans and reader probes. A probe must not overwrite the evidence that selected an action.
- Use bounded logs, queues, repeat observations, and explicit dropped counters. Errors retain native domain/code plus a short label.

## RAM and verification

- Use target ARM `.su` files, linked section sizes, `-Wstack-usage`, native type definitions, and allocator overhead. Host sanitizer builds remain valuable but cannot prove target enum width or heap headroom.
- Model concurrent allocations per stage: application/model, worker stack, queue, strings, native device/protocol state, file payloads, growth overlap, and a reserve. Reject safely before allocation when free heap or largest block is insufficient.
- Run model, NFC, LF, reader, file/session, workflow/capability, and production-renderer host tests; run sanitizers where supported. Then run native FBT with warnings as errors, APPCHK, API import checks, and exact embedded-icon comparison.
- Record physical-device gaps honestly: RF coupling/detection, reader exchanges, contention, cancellation drain, SD power-loss behavior, USB logs, Dolphin XP, handoffs, actual recovery/write results, display appearance, and runtime memory remain unproved until tested on hardware.

## Distribution and publication

- Release `nfc_diagnostic_suite.fap` as the primary asset. Optional installer ZIP contains only the FAP, README, project license, source icon, and build record.
- Do not put tests, source C/H files, internal PBM/GIF/PNG captures, firmware trees, backups, caches, private card files, nonce logs, dictionaries, or third-party app binaries/source/notices in the installer ZIP. Source and tests can remain in the public repository.
- Do not redistribute compatible native applications. Documentation may describe optional runtime handoffs without presenting those applications as bundled dependencies.
- Keep public README focused on install/use/build/proof limits; do not list assumed preinstalled applications.
- Verify ZIP members exactly, record SHA-256 for the FAP and ZIP, and keep build revision/API evidence.
- Creating or updating a public repository or release requires explicit user authorization at that time. The 2026-10-15 authorization applied to this suite's requested release only and must not be reused for future repositories or releases.

## Follow-up workflow and review requirements

- Reuse the IR app's native `elements_button_left/center/right` bar, including its directional/OK glyphs. Remove redundant control hints. Show File only where an input file is useful, including live card scans; hide it on passive reader and final saved steps. Hidden controls must be inert.
- During NFC card scans and NFC field/request reader tests, OK switches to LF after cancellation drains. Classic capture uses OK/Done instead. The combined reader field scan already samples both bands and needs no redundant switch.
- Retry NFC identification once before automatic LF fallback; bound all retries, preserve earlier errors and never restart a user-cancelled operation. Unknown results remain unknown, including non-RFID objects and unsupported reader protocols.
- Preserve exact caller navigation: standalone Reader Back returns Home; workflow Reader Back returns its workflow/tools caller; live Log Back returns scanning; active Back drains then returns its caller; file cancel and confirmation cancel return to their originating step/submenu. Retain menu selection where possible.
- Keep reader fingerprints as observed characteristics with probe mode, stimulus, metric availability, sample timing and strict versioned checksums. Compare only compatible, sufficiently rich contexts. Similar timing/rates never prove identity or reader brand. Save profiles beside their session; reject orphan profiles. Bound history scanning and report truncation.
- Group new card/reader diagnostic reports and logs under a user-selected system, preserving native card files and old ungrouped sessions. Persist selection atomically, validate safe names and bound system creation. Surface partial saves and native storage errors rather than silently changing destination.
- Keep protocol capability references and offline likely-cause/next-test advice under existing Tools/Sessions, with evidence/limitations explicit. Avoid new top-level clutter.
- Use a brief ascending success tone, descending failure tone, and subtle haptics through firmware notifications. Honor speaker/vibration/stealth settings. Passive/no-evidence/cancel/retry transitions stay quiet; durable reader capture completion may signal once, whether automatic or Done.
- Classic capture displays minimum one usable pair (two distinct complete matching contexts). Ideal coverage depends on every needed sector/key, with no universal pair count. Done remains usable before the minimum; drain and sync before offering Decode. A saved/already-existing usable pair with no append error is required. Readiness is not a recovered key.
- Run a final small review swarm covering UI and each critical system, then an independent whole-integration review. Resolve findings and repeat affected reviews plus final integration until no actionable issues remain. Keep physical-device acceptance separate.

## mntm-012 RF dependency limits found during review

The live suite avoids the broad native scanner because its EMV detect path enters an unchecked PPSE TLV parser; bounded base-tech native pollers and existing direct family probes preserve diagnostic coverage. Do not reintroduce the broad scanner on this pin without resolving that parser boundary. Native ISO14443-A activation also lacks a repeated-cascade bound; standard 4/7/10-byte cards are intended inputs. Hostile out-of-spec RF responder hardening requires a firmware fix or a separately scoped replacement stack. Native ISO-DEP WTX and Plus/DESFire AF continuation can also prevent timely drain. Do not claim the app fixes these inherited firmware limits or silently modify the read-only dependency tree.
