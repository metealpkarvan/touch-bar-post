# Changelog

## 1.2.0 · 2026-10-05

- Make saving several notes clearer with **+ New note**, **Save new** and **Update** labels in the same compact editor.
- Keep saved-message navigation and the selected message across restarts without automatic rotation.
- Add a persistent global Touch Bar strip-width setting from 240 to 560 points, defaulting to 400 points.
- Show the requested strip width in the desktop preview and apply it to the physical AppKit message item.
- Keep archive version 1, existing message identities and metadata; archives without the new width preference use the default.
- Retain the separate new-note Touch Bar button and document that macOS owns the Control Strip and available app space.
- Retain Universal Intel/Apple Silicon macOS 11+ packaging and safe draft, backup and recovery behaviour.
- Verify 71 core and 44 AppKit integration checks using fictional records and temporary storage; repeat all 44 on the packaged Intel slice and validate Universal slices, signature and ZIP permissions.

## 1.1.0 · 2026-10-05

- Replace the dashboard with one compact window, three message types, one text field and Save.
- Put all active messages from former scenes in one list; preserve existing v1 records and metadata.
- Remember the selected message across launches and keep it on the strip without automatic rotation.
- Scroll announcements only; keep notes and reminders still and respect Reduce Motion.
- Add reminder-only +5/+15/+60 minute shortcuts, completion and five-minute postponement.
- Save valid drafts on message changes, window close and quit; retain drafts and block navigation after failed writes.
- Keep optional notifications, privacy, language and data recovery in native menus.
- Use Turkish/English date input locales and retain the Universal macOS 11+ package.
- Verify 63 core and 33 AppKit integration checks with temporary data and rendered native screenshots.

## 1.0.0 · 2026-10-05

- Native Turkish/English announcement, note and one-shot reminder desk.
- Desk/Break/Home scenes, due priority, pinning, hold and curtain.
- Shared physical Touch Bar, window and optional floating strip controls.
- Explicit notification permission, serialized OS scheduling, postponement and completion.
- Bounded JSON backups, Markdown export, previous archives and raw recovery copies.
- Universal Intel/Apple Silicon macOS 11+ packaging and native CI checks.
