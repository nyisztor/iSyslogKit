/// Severity of a log entry, mirroring the unified logging levels.
///
/// Encoded by name so session files stay readable and independent of the raw ordering.
public enum LogLevel: String, Codable, Sendable, CaseIterable, Comparable {
    case debug
    case info
    case notice
    case error
    case fault

    /// Position in the severity order, from `debug` (0) to `fault` (4).
    public var severity: Int {
        switch self {
        case .debug: 0
        case .info: 1
        case .notice: 2
        case .error: 3
        case .fault: 4
        }
    }

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.severity < rhs.severity
    }
}
