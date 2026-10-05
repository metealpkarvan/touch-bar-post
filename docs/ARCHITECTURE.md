# Architecture

`PostCore` owns the version-1 Codable archive, validated mutations, ordering, notification eligibility, Markdown export and atomic file storage. `simpleQueue` includes active messages from every former scene, placing due reminders first, then pinned messages, then newer messages with stable identity tie-breaks. The older scene queue remains available for compatibility checks.

`Card.messageText` adapts the old title/body fields to one editor. Unchanged legacy text keeps its original field boundaries. Edits update only title/body while preserving identity, creation date and other metadata. The limits remain 80 title graphemes and 400 body graphemes; invalid edits are rejected before mutation.

`Settings.selectedCardID` is optional, so old archives without it decode unchanged. A present selection must point to an active record. Completing or removing that record clears the reference in the same validated transaction. Archive version 1 and the original Application Support location are retained.

`DeskController` owns the compact native editor, list, status menu, preview and physical strip. A saved selection drives the display. A newly due reminder can temporarily override the displayed message without changing the editing buffer or stored selection. The timer compares deadlines with wall time; it never rotates ordinary messages. Changing language also changes the date-picker locale without clearing a draft.

A save validates a complete candidate, persists it, then commits the visible archive. Failure preserves entered text and the previous model. Navigation, close and quit save valid drafts first. An unreadable archive blocks ordinary writes and offers raw export or explicit recovery through the Data menu. Import and previous-record recovery validate before replacement, preserve a raw recovery copy and disable notifications until explicitly re-enabled.

`RailView` shares four NSButton callbacks between the preview and the principal Touch Bar item: previous, message, next and the kind-specific action. The physical item has a 240-point minimum and flexible width, plus one new-note item. Only announcements animate; foreground state, the legacy motion preference and Reduce Motion gate animation. Text is plain content and is never executed.

`NotificationDesk` requests authorization only through the user's explicit menu action. It serializes scheduling and reconciles the latest desired archive after each batch. Up to 60 future active reminders use stable IDs, full calendar dates, current time zone and quiet, non-repeating requests. Privacy substitutes generic future content and removes delivered notifications belonging to this app. Notifications can open their corresponding message.

macOS owns requests already scheduled while the app is closed. Delivery remains subject to permissions, Focus, sleep and system policy. Past deadlines stay due in the app without replaying an old system alert. There are no repeat rules, network services, login items or external package dependencies.

`ArchiveStore` uses atomic Foundation writes and retains the previous valid archive. The package script builds x86_64 and arm64 for macOS 11, combines them with lipo, verifies both slices and the ad-hoc signature, runs packaged AppKit acceptance and creates a UTF-8 ZIP with guides and SHA256. Native arm64 execution is verified separately in CI.
