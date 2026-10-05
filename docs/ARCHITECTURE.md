# Architecture

`PostCore` owns validated Codable records, selection order, state mutations, notification eligibility, search folding, Markdown and file storage. Dates are injected into rule checks. Replacement is built as a complete candidate, validated before it becomes application state. Storage writes use Foundation atomic file replacement. A normal write preserves the previous valid archive; explicit import/reset keeps raw recovery bytes first.

`DeskController` owns the native editor, scene controls, menu item, shared strips, timers and backup panels. An unreadable archive puts the real editor into a protected state. A failed save leaves the original model and entered fields available for correction. Imports are validated before confirmation and notifications are explicitly disabled after import.

`RailView` has four real AppKit buttons: previous, message, next and kind-specific action. The principal Touch Bar item has a flexible width and a 240-point minimum. The view uses the same callbacks in the main window, physical item factory and floating panel. Text is plain content and is never executed.

`NotificationDesk` requests system authorization only through an explicit action. It serializes scheduling batches and reconciles the latest desired archive after a batch completes, so quick edits/deletion do not leave a stale final schedule. The plan contains up to 60 future, incomplete reminders. Each request has a stable card ID, full calendar date, current time zone and no repetition or requested sound. Curtain substitutes generic text and removes delivered notifications belonging to this app. An incoming notification opens its card.

An app process is not required for already scheduled OS notification requests, but notification delivery is an OS decision. Older deadlines are kept in the in-app queue without rescheduling them. The model stores absolute instants; changing a clock or waking from sleep is handled by comparing against wall time on each tick. There are no repeat rules, network services, login items or external libraries.

Apple documents the frontmost-app scope in [NSTouchBar](https://developer.apple.com/documentation/appkit/nstouchbar). Notification authorization follows [requestAuthorization](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/requestauthorization(options:completionhandler:)).

Swift Package Manager builds both slices for macOS 11. `scripts/package.sh` combines them with lipo, verifies architecture presence, ad-hoc signs and verifies the bundle, runs AppKit smoke checks on the host slice, and creates a ZIP with guides and SHA256. Native arm64 behavior is checked separately by CI, not inferred from successful cross compilation.
