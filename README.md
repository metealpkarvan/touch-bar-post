# Şerit · Touch Bar Post

Save several notes, set a reminder, or scroll an announcement on your MacBook's Touch Bar. One window, one message field and one saved-message list. Choose how wide the message strip should be. Native Swift/AppKit for macOS 11+, with a Universal Intel and Apple Silicon app.

[Download the app](https://github.com/metealpkarvan/touch-bar-post/releases/latest) · [Türkçe](README.tr.md)

![Actual native macOS interface](docs/desktop-en.png)

## Three simple jobs

- **Note:** Write a message and save it. It stays on the strip until you select another message or a reminder becomes due. Tap its centre to edit it; use Copy to copy its text.
- **Reminder:** Write a message, choose a date/time or use +5, +15 or +60 minutes, then save. When due, it takes priority. Complete it with ✓ or postpone it five minutes.
- **Announcement:** Write and save a message. Long announcements scroll; notes and reminders stay still. macOS Reduce Motion is respected.

Saved messages appear together in one list. Use **+ New note**, write another message and press **Save new** to add it without replacing a previous note. Select a saved message to edit or show it; **Update** saves changes to that record. **Delete** removes only the selected message. The on-screen strip has the same actions as the Touch Bar: previous, message, action and next. The Touch Bar's **+** starts a new note.

Use the **Touch Bar space** slider to choose a strip width from **240 to 560 points**. The default is **400 points**. The exact value appears beside the slider, and the on-screen preview shows the requested width. Release the slider to save your choice; it applies to every message and survives reopening. The physical strip can become narrower if macOS provides less space. The separate **+** button and macOS Control Strip also need room.

Your chosen message is remembered after reopening. Valid edits also save when you switch messages, close the window or quit. If saving fails, the draft stays available and navigation stops. An empty editor leaves the saved message intact; use **Delete** to remove it.

![Announcement strip](docs/touchbar-announcement.png)
![Reminder strip](docs/touchbar-reminder.png)

Rendered message strips at the minimum and maximum requested widths:

![Compact 240-point strip](docs/touchbar-compact.png)
![Wide 560-point strip](docs/touchbar-wide.png)

## Install and use

Download [`TouchBarPost-v1.2.0-universal.zip`](https://github.com/metealpkarvan/touch-bar-post/releases/tag/v1.2.0), unzip it and move **Şerit.app** to Applications. Open it, press **+ New note**, choose **Note**, **Reminder** or **Announcement**, write a short message and press **Save new**. A reminder also needs its date/time. Repeat **+ New note → Save new** to keep several separate notes. Select a saved row when you want to edit it with **Update**. Notifications, backup/import and Turkish/English are in the native menus.

To update, quit the older Şerit with **⌘Q**, optionally export a JSON backup from **Data**, then replace only **Şerit.app** with the new app. Keep `~/Library/Application Support/TouchBarPost/` in place: that folder holds your records. Existing version 1 archives remain compatible: old messages, their titles, descriptions and metadata are retained. An older archive without a saved width opens at 400 points. Messages from every former scene appear in the same list; previously pinned messages keep their priority. The simplified interface does not rotate messages automatically.

The app is ad-hoc signed for integrity, without Developer ID signing or Apple notarization. If Gatekeeper blocks first launch, attempt to open the app, then use **System Settings → Privacy & Security → Open Anyway**. Wording varies by macOS. No system-wide security changes are needed. Releases include source links and SHA256 checksums.

## Touch Bar and reminders

The public AppKit Touch Bar displays the **frontmost app's** controls. Şerit does not replace other apps' Touch Bars. macOS owns the system Control Strip and can constrain the available app area; the width setting is the requested width of Şerit's message strip, not a reservation of the whole Touch Bar. Closing the window leaves Şerit running in the menu bar; **⌘Q / Quit** ends it. A physical Touch Bar needs a supported MacBook Pro. The on-screen strip works on Intel and Apple Silicon Macs without a Touch Bar.

System notifications are optional. Permission is requested only when you choose to enable them from the menu. When enabled, the earliest **60 future active reminders** are scheduled as one-shot local notifications; macOS manages those requests even after Şerit quits. Other reminders join the plan when Şerit next runs. Delivery depends on permission, Focus, sleep and OS policy. Past deadlines remain due in the app without replaying an old system alert. Reminders do not repeat automatically. Local date/time input is saved as an instant.

**Şerit → Hide Touch Bar text** conceals the strip and menu message titles, removes this app's delivered alerts, and uses generic content for future notifications. The editor remains visible. This preserves an older archive's privacy choice; uncheck it in the menu to show messages again.

## Local data

Messages, the selected message and the strip-width preference are saved at `~/Library/Application Support/TouchBarPost/archive.json`, unencrypted. No account, cloud, analytics, AI API or background network calls. The archive holds up to 200 messages; JSON backups are limited to 1 MB.

The data menu provides JSON backup/import, recovery of the previous archive, Markdown export and the archive folder. Validated saves retain `archive.previous.json`. Import or recovery creates a separate recovery copy before replacing records. A corrupt archive is protected from writes and can be exported byte-for-byte. Import and recovery disable notifications until you enable them again. Recovery copies remain until you remove them.

## Build and verify

```bash
swift run --disable-sandbox -j 2 PostRulesTests
swift build --disable-sandbox -j 2 --product TouchBarPost
.build/debug/TouchBarPost --smoke-test --screenshots output/verification
bash scripts/package.sh 1.2.0
```

Requires Xcode Command Line Tools and Swift 5.7+. Packaging uses Python 3's standard ZIP library to retain UTF-8 names and executable permissions; app users need neither Swift nor Python. System notifications require the packaged `.app`. There are no external package dependencies.

CI runs rules and actual AppKit item/action checks on native Intel and arm64 hosts before verifying Universal packaging. Tests use fictional messages and temporary files, without clipboard writes or notification permission requests. [Verification](docs/VERIFICATION.md) separates automated checks from physical-device and notification-delivery tests.

[Design](docs/DESIGN.md) · [Architecture](docs/ARCHITECTURE.md) · [Hardware checklist](docs/HARDWARE-CHECKLIST.md) · [Roadmap](docs/ROADMAP.md)

MIT © 2026 Mete Alp Karvan
