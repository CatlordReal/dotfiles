# Release troubleshooting

## Account and signing

An existing Xcode owner account may support `xcodebuild` export and upload without an API key. Confirm the selected paid Developer Program team and App Store Connect role separately; a personal team or an App Store Connect role alone does not establish paid-team provisioning access. Reuse working credentials. A long `codesign` or export operation is not evidence of a human prompt; a locked session may pause progress, and `caffeinate` does not unlock it. Verify a visible prompt before asking for action. If SecurityAgent or the system authorization UI is hard-blocked, hand off to the user; do not seek alternate capture or bypass security.

## Scoped unattended signing

With explicit consent for access to the existing protected signing key, the optional `scripts/release-export.py` helper may create a password-protected temporary keychain, import only the intended identity, scope access and key partitions to that keychain, verify a disposable signature, run export, and restore the search list and delete temporary material. Never alter login-keychain ACLs or partitions, revoke credentials, or automate SecurityAgent. Serialize signing and search-list changes. This approach may work while the Mac is locked; require an actual locked-session test before claiming it does. macOS `security` noninteractive password arguments expose the disposable password to local process inspection while the command runs; never log them. Document abrupt-termination recovery and verify cleanup.

## Artifact and distribution

Inspect actual archived and exported `Info.plist` values before upload: `CFBundleShortVersionString` can remain hardcoded despite `MARKETING_VERSION`. Check `CFBundleVersion`, bundle ID, signing team, entitlements, background task identifiers, embedded primary icon, profile and signature against release intent. `scripts/release_preflight.py` checks a subset; it does not establish distribution eligibility, team, entitlements, icon appearance or App Store acceptance. For unsigned archives use `--metadata-only`; this is never signing-ready evidence. Check exported IPA again.

`testFlightInternalTestingOnly=true` creates an internal-only upload that cannot be used for external testing. Keep shared and experimental releases on separately frozen source revisions or branches with distinct build numbers, and inspect export options before upload. Track initial external beta review separately from tester invitations and public-link enablement: an email-only friend test does not require enabling a public link. Use the developer's own authorized reviewer contact number and an appropriate feedback email/reply-to; do not invent contact details. A recurring status checker requires explicit scheduling consent.

## Browser interaction

When Safari accessibility actions silently fail, identify the exact existing window using its Window menu UUID and inspect a fresh accessibility snapshot. Use screenshot-relative pixel clicks when appropriate. For text fields, click and type text if accessibility `setValue` or paste fails. A new tab in a known working window may work when a new-window click fails. Wait for asynchronous loading, then inspect fresh accessibility state before another action; do not spam clicks. Never treat a click without observed state change as success.
