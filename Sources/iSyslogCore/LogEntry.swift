import Foundation

/// One captured log message.
public struct LogEntry: Codable, Hashable, Sendable, Identifiable {
    /// Where the entry was captured from.
    public enum Origin: String, Codable, Sendable {
        /// The unified log (`Logger`, `os_log`).
        case osLog
        case standardOutput
        case standardError
        /// Logged directly through iSyslogKit.
        case direct
    }

    public var id: UUID
    public var date: Date
    public var level: LogLevel
    public var message: String
    /// Empty when the message was logged without a subsystem.
    public var subsystem: String
    public var category: String
    public var process: String
    public var processID: Int32
    public var threadID: UInt64
    /// The library or executable that logged the message, e.g. `UIKitCore`.
    public var sender: String
    public var origin: Origin

    public init(
        id: UUID = UUID(),
        date: Date,
        level: LogLevel,
        message: String,
        subsystem: String = "",
        category: String = "",
        process: String = "",
        processID: Int32 = 0,
        threadID: UInt64 = 0,
        sender: String = "",
        origin: Origin = .osLog
    ) {
        self.id = id
        self.date = date
        self.level = level
        self.message = message
        self.subsystem = subsystem
        self.category = category
        self.process = process
        self.processID = processID
        self.threadID = threadID
        self.sender = sender
        self.origin = origin
    }

    /// Messages Apple's frameworks log inside the app's process (UIKit, CFNetwork, …).
    /// They make up most of the volume, so consoles hide them unless asked.
    ///
    /// Some system libraries log without a subsystem; those are recognized by coming from
    /// a library other than the app's executable.
    public var isSystemMessage: Bool {
        if subsystem.hasPrefix("com.apple.") { return true }
        return subsystem.isEmpty && !sender.isEmpty && sender != process
    }
}
