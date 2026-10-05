# Verification · 1.2.0 · 2026-10-05

The local verification host is an Intel Mac running macOS 15.8 and Swift 6.1.2. macOS 11 is the deployment target, not a claim of testing every older operating system. The 1.2.0 source passed 71 core and 44 AppKit integration checks. The Universal package also passed all 44 checks on its Intel host slice, signature validation and ZIP-integrity checks. These local results do not assert native arm64 execution or verification of a public download.

## Core behavior

**71 core checks** passed for 1.2.0. They cover archive bounds, Turkish and emoji strings, one-field editing, unchanged legacy text, metadata preservation, optional persisted selection, invalid references, v1 decoding, all-scene visibility, stable due/pin/time ordering, atomic completion/removal, snooze constraints, notification eligibility/cap, Markdown, atomic storage, previous archives and raw recovery copies. The updated checks also cover the width default, bounds, malformed values, old-archive decoding and round trip, plus retaining several separate notes and their metadata. Fixtures use fixed dates and temporary directories. The published 1.1.0 baseline had 63 core checks.

## Native AppKit acceptance

**44 integration checks** passed against the actual 1.2.0 editor and NSTouchBar factory. They exercise exactly three message types and two physical items, previous/next/copy/new/delete actions, no automatic rotation, legacy editing metadata, draft auto-save, selection persistence, announcement-only motion, reminder shortcuts, language and date locale, due preemption, completion, snooze and privacy. Request construction checks stable notification IDs, quiet one-shot triggers and generic private content. The published 1.1.0 baseline had 33 integration checks.

The new acceptance checks create three independent notes, select a real list row, update one note without changing the others and delete one without removing its neighbours. They invoke the width slider at 240, 560 and 431 points, check the exact desktop preview and physical item constraints, retain an unsaved editing buffer, preserve an in-progress slider position through timer refresh and restore saved notes, selection and exact width when reopening the controller. An AppKit layout host constrains a 560-point preference to 300 available points and verifies usable controls after compression.

Storage checks invoke the real Save action against corrupt and unwritable temporary records. They verify unchanged original bytes, retained drafts, blocked navigation and a successful retry after storage repair. A failed width save restores the previous slider and preview width without discarding the draft. Oversized messages cannot partially change a saved record.

The same 44 checks run with or without screenshots. `--screenshots` renders the native Turkish/English window, reminder editor and real strip views. The Turkish/English windows and 240/560-point strips were visually inspected locally and copied into `docs/`. Screenshots are rendered AppKit views, not photographs of a hardware Touch Bar. The test process has prohibited activation policy, creates no visible windows, requests no permission, schedules no notifications and uses an injected copy sink rather than the real clipboard. It never loads live user records.

## Distribution and architecture

The local package contains x86_64 and arm64 slices targeting macOS 11. `lipo` verified both architectures, strict `codesign` verification passed, and the ZIP check confirmed UTF-8 names and executable permissions. The packaged Intel host slice passed all 44 AppKit checks. Compiling and inspecting the arm64 slice does not prove execution on an Apple Silicon host.

The CI workflow asserts native CPU identity on Intel (`macos-15-intel`) and arm64 (`macos-latest`). Both jobs are configured to run core checks, build the app and run AppKit acceptance. The Universal packaging job depends on both and repeats slice, signature and packaged acceptance checks. Consult [Actions](https://github.com/metealpkarvan/touch-bar-post/actions) for achieved results at the exact source revision used for a release.

```bash
swift run --disable-sandbox -j 2 PostRulesTests
swift build --disable-sandbox -j 2 --product TouchBarPost
.build/debug/TouchBarPost --smoke-test --screenshots output/verification
bash scripts/package.sh 1.2.0
```

Release archives include the app, English/Turkish guides and source documentation. SHA256 accompanies each download. Distribution verification consists of downloading the public asset, matching its checksum, checking its architecture and signature, and running the packaged acceptance harness; local packaging alone does not establish that those public-asset checks passed. Ad-hoc signing checks bundle integrity; Developer ID signing and Apple notarization are not supplied.

Physical finger input, Control Strip ergonomics, real notification delivery with the app closed, every Mac/OS version, full VoiceOver behaviour and regional clock changes remain manual checks in [HARDWARE-CHECKLIST.md](HARDWARE-CHECKLIST.md). Automated results do not replace them.
