# A small postal desk

Şerit turns a narrow strip into a personal message surface. The product starts with three distinct intentions: an announcement can be seen, a note can be copied, and a reminder can be completed. The action button follows that intention instead of guessing from the text.

The dark desk and four stamp inks are drawn with AppKit primitives. No external stock imagery, copied interface or generated branding asset is included. The envelope icon and screenshots are produced by the repository’s own code.

Scenes offer context without accounts or automatic location tracking. Desk, Break and Home are fixed names in version 1. Due reminders deliberately cross scene boundaries so switching to a work scene does not bury a personal reminder. Pinned cards only outrank ordinary scene cards; a due reminder remains first.

A person controls the pace. A two-second pause precedes long-text scrolling, cards rotate every twelve seconds when no reminder is due, and manually selecting a card holds the strip. Reduce Motion suppresses text animation. Privacy curtain disables strip copying while concealing its content. It is a display aid, not data encryption.

The physical and desktop strips share the same NSButton actions. Their centre opens the full editor; long notes are readable there even with motion disabled. The editor uses labelled native fields, a plain text view, a date picker, keyboard menus and accessible button labels. A full VoiceOver audit and physical Touch Bar ergonomics session remain future work.

Public AppKit APIs constrain the Touch Bar to the frontmost app. A menu item and optional floating strip offer practical return paths. The app does not use private global Touch Bar APIs, system injection or accessibility interception.
