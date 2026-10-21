# Changelog

## 0.1.0

First public release.

- Captures the app's own unified-log messages (`Logger`, `os_log`) and `print` output, in Debug and TestFlight builds by default
- In-app SwiftUI console: severity summary and chart, search, level, subsystem and category filters, entry details
- Shares a session as a `.isyslog` file through the share sheet, for the free iSyslog app
- Opt-in shake to open, and `ISyslogShareSheet.shareCurrentSession()` for your own "Report a Problem" button
- iOS 17+, macOS 14+, Swift 6
