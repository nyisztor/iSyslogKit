# Privacy Policy

_Last updated: October 21, 2026_

This policy covers the **iSyslog** app for iPhone and iPad and the **iSyslogKit** Swift package, both made by Karoly Nyisztor.

## iSyslog

iSyslog doesn't collect, store or share any personal data.

- It has no accounts, analytics, advertising or tracking, and it doesn't connect to any server.
- Log sessions you open in iSyslog are stored only on your device, in the app's own storage, until you delete them. They're included in your device backups like other app data.
- Log sessions can contain information the app that created them logged. iSyslog only displays them; it doesn't send them anywhere. If you share a session from iSyslog, it goes only where you send it.

## iSyslogKit

iSyslogKit is a library that developers add to their own apps. It runs inside those apps and doesn't collect or send any data to its author or anyone else.

- It reads the log messages and `print` output of the app it's built into, keeps them in memory, and shows them in an in-app console.
- By default it's only active in Debug builds and TestFlight installs, not in apps downloaded from the App Store.
- It writes a session file only when the user taps Share (or the app calls the sharing API), and the file goes only where the user sends it.

Developers who use iSyslogKit are responsible for what their apps log and for their own privacy policies.

## Contact

Questions about this policy: open an issue at https://github.com/nyisztor/iSyslogKit/issues.
