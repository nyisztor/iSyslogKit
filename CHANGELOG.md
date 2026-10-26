# Changelog

## Unreleased

- Fixed: a live console that fell behind (more than 32 pending updates) silently lost entries. The capture now resends everything it holds when a subscriber's updates overflow.
- Changed: `LogCapture.subscribe()` streams `LogCapture.Update` values instead of `[LogEntry]` batches. Check `replacesEarlierEntries`: when true, `entries` replaces everything received before. A new `pendingUpdateLimit` parameter (default 32) sets how many updates wait for a slow subscriber.

## 0.1.0

First public release.

- Captures the app's own unified-log messages (`Logger`, `os_log`) and `print` output, in Debug and TestFlight builds by default
- In-app SwiftUI console: severity summary and chart, search, level, subsystem and category filters, entry details
- Shares a session as a `.isyslog` file through the share sheet, for the free iSyslog app
- Opt-in shake to open, and `ISyslogShareSheet.shareCurrentSession()` for your own "Report a Problem" button
- iOS 17+, macOS 14+, Swift 6
