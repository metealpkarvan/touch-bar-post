# One message, one action

Şerit 1.1 starts with three choices: Note, Reminder and Announcement. The window has one plain-text field and a Save button. Only reminders show the date/time input and +5/+15/+60 minute shortcuts. Saved reminders also show Done and Snooze 5 min.

One list contains all active messages. New starts another message; Delete removes the selected record. A chosen message stays on the strip and is remembered after reopening. A newly due reminder takes temporary priority without replacing text currently being edited. There is no automatic message rotation.

Announcements alone can scroll. Notes and reminders remain still; tapping the strip's centre opens the full editor. A two-second pause precedes long announcement scrolling, and macOS Reduce Motion suppresses it. Previous, message, action and next use the same native buttons in the window and the physical Touch Bar. The physical bar adds a single + button for a new note.

The compact dark interface and app icon are drawn with native AppKit primitives. Screenshots are rendered from the working app, using fictional records. No generated mockup is presented as running software.

Scene, pin and colour controls from version 1.0 are removed from the editor. Existing metadata stays in the archive; old pinned messages retain list priority. Backup/recovery, notification permission, privacy and language are in native macOS menus. No account or setup wizard is needed.

Valid drafts save when navigating to another message, closing the window or quitting. A failed save retains both the draft and the previous archive and prevents navigation. Emptying the editor does not erase a saved message; deletion is explicit.

The privacy menu conceals strip text and message titles in the status menu. It is a display preference, not encryption: the editor and local archive remain readable. Public AppKit Touch Bars follow the frontmost app. The window preview provides the same controls on Macs without that hardware.
