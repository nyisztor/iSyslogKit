import Foundation
import OSLog
import iSyslogCore

/// Reads the app's own entries from the unified log.
///
/// A query takes about 1.5 s on device (3 s with 10k entries) and blocks, so this class is
/// only ever used on `LogCapture`'s serial queue, never on the main thread or the actor.
final class OSLogStoreSource: @unchecked Sendable {
    private var cursor = IncrementalCursor()

    /// Entries logged since the previous call, oldest first.
    func fetchNewEntries() throws -> [LogEntry] {
        // Reopen every time: on macOS an open store is a snapshot that never sees new
        // entries, and on iOS opening costs about a millisecond.
        let store = try OSLogStore(scope: .currentProcessIdentifier)

        // After the first full read, let the log service do the filtering: a date predicate cost
        // ~1.6 s and almost no app CPU on device with 10k entries, while a full scan took ~3 s and
        // 0.6 s CPU and keeps growing with the log. `.reverse` and `position(date:)` don't narrow
        // anything on iOS or macOS.
        let entries: AnySequence<OSLogEntry>
        if let since = cursor.lastDate {
            // `>=` keeps entries sharing the last timestamp; the cursor drops the ones already delivered.
            entries = try store.getEntries(matching: NSPredicate(format: "date >= %@", since as NSDate))
        } else {
            entries = try store.getEntries()
        }
        let logs = entries.lazy.compactMap { $0 as? OSLogEntryLog }
        // Only convert what's new: composedMessage is the expensive part.
        return cursor.newElements(in: logs, date: \.date).map(LogEntry.init)
    }
}

extension LogEntry {
    init(_ log: OSLogEntryLog) {
        self.init(
            date: log.date,
            level: LogLevel(log.level),
            message: log.composedMessage,
            subsystem: log.subsystem,
            category: log.category,
            process: log.process,
            processID: log.processIdentifier,
            threadID: log.threadIdentifier,
            sender: log.sender,
            origin: .osLog
        )
    }
}

extension LogLevel {
    init(_ level: OSLogEntryLog.Level) {
        switch level {
        case .debug: self = .debug
        case .info: self = .info
        case .error: self = .error
        case .fault: self = .fault
        // `.undefined` is what plain os_log calls without a type report; that's the default (notice) level.
        case .notice, .undefined: self = .notice
        @unknown default: self = .notice
        }
    }
}
