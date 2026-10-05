# Verification · 2026-10-05

The local verification host is an Intel Mac, macOS 15.8, Swift 6.1.2. The deployment target is macOS 11, not a claim of physical testing on every older OS.

## Core behavior

44 checks cover bounded records/imports, Turkish/emoji strings, invalid and duplicate identities, date validation, scene and due priority, deterministic ordering, completion/restore, snooze constraints, edit atomicity, notification eligibility/cap, search folding, Markdown, previous archives, corrupt-record protection and raw recovery copies. Test fixtures use fixed dates and temporary directories, without altering user records.

## Native AppKit acceptance

19 baseline checks exercise the actual NSTouchBar item factory, three scene choices, pin rendering, previous/next NSButton actions, privacy masking, quick note creation, unsaved state detection, editing identity, due transition after a wall-clock advance, shared preview completion, scene mutation, notification request ID/content/trigger/sound, reopening a saved archive and corrupt-file protection through the real editor.

When `--screenshots output/verification` is supplied, two additional checks switch the real language button to English and back while preserving an unsaved draft. Total: **21 AppKit checks** in the CI/verification command. Native desktop and strip screenshots are rendered using AppKit, and the working layouts are visually inspected locally. They are rendered app/item views, not photographs of a physical Touch Bar.

The smoke process requests no notification authorization, schedules no system notifications and writes no clipboard data. It checks construction of local notification requests; actual delivery, Focus and sleep policy are separate device checks. A corrupt fixture is retained byte-for-byte even when a user-equivalent Save action is invoked.

## Distribution and architecture

CI contains native Intel (`macos-15-intel`) and arm64 (`macos-latest`) jobs with explicit CPU assertions. Each runs the same rules, builds the app and runs AppKit acceptance. The packaging job waits for both, cross builds x86_64/arm64 for macOS 11, combines with lipo, verifies both slices and ad-hoc signing, and runs baseline AppKit checks on the packaged host slice. Actual run results are in [Actions](https://github.com/metealpkarvan/touch-bar-post/actions).

The ZIP includes the application and English/Turkish guides. SHA256 checks accompany releases. Ad-hoc signing verifies bundle integrity; Developer ID signing and Apple notarization are not supplied.

Physical Touch Bar width/tap behavior, actual notification delivery with the app quit, every supported Mac/OS, full VoiceOver behavior and all regional date formats remain manual checks in [HARDWARE-CHECKLIST.md](HARDWARE-CHECKLIST.md). Automated results do not replace those checks.
