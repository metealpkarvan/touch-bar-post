# Verification · 1.1.0 · 2026-10-05

Local verification uses an Intel Mac running macOS 15.8 and Swift 6.1.2. macOS 11 is the deployment target, not a claim of testing every older operating system.

## Core behavior

**63 core checks** cover archive bounds, Turkish and emoji strings, one-field editing, unchanged legacy text, metadata preservation, optional persisted selection, invalid references, v1 decoding, all-scene visibility, stable due/pin/time ordering, atomic completion/removal, snooze constraints, notification eligibility/cap, Markdown, atomic storage, previous archives and raw recovery copies. Fixtures use fixed dates and temporary directories.

## Native AppKit acceptance

**33 integration checks** exercise the actual compact editor and NSTouchBar factory: exactly three message types and two physical items, previous/next/copy/new/delete actions, no automatic rotation, legacy editing metadata, draft auto-save, selection persistence, announcement-only motion, reminder shortcuts, language and date locale, due preemption, completion, snooze and privacy. Request construction checks stable notification IDs, quiet one-shot triggers and generic private content.

Storage checks invoke the real Save action against corrupt and unwritable temporary records. They verify unchanged original bytes, retained drafts, blocked navigation and a successful retry after storage repair. Oversized messages cannot partially change a saved record.

The same 33 checks run with or without screenshots. `--screenshots` renders the native Turkish/English window, reminder editor and real strip views. Those images are visually inspected locally; they are not photographs of a hardware Touch Bar. The test process has prohibited activation policy, creates no visible windows, requests no permission, schedules no notifications and uses an injected copy sink rather than the real clipboard. It never loads live user records.

## Distribution and architecture

CI asserts native CPU identity on Intel (`macos-15-intel`) and arm64 (`macos-latest`). Both run core checks, build the app and run AppKit acceptance. The Universal packaging job depends on both, cross-compiles x86_64/arm64 for macOS 11, verifies both slices and the signature, and runs all 33 checks on the packaged host slice. Actual results appear in [Actions](https://github.com/metealpkarvan/touch-bar-post/actions).

Release archives include the app, English/Turkish guides and source documentation. SHA256 accompanies each download. Ad-hoc signing checks bundle integrity; Developer ID signing and Apple notarization are not supplied.

Physical finger input, Control Strip ergonomics, real notification delivery with the app closed, every Mac/OS version, full VoiceOver behaviour and regional clock changes remain manual checks in [HARDWARE-CHECKLIST.md](HARDWARE-CHECKLIST.md). Automated results do not replace them.
