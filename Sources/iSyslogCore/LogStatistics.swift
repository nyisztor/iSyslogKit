/// Counts behind the console's severity summary and pie chart.
public struct LogStatistics: Sendable, Equatable {
    public private(set) var total = 0
    public private(set) var countsByLevel: [LogLevel: Int] = [:]
    public private(set) var countsBySubsystem: [String: Int] = [:]

    public init<S: Sequence>(_ entries: S) where S.Element == LogEntry {
        for entry in entries {
            total += 1
            countsByLevel[entry.level, default: 0] += 1
            countsBySubsystem[entry.subsystem, default: 0] += 1
        }
    }

    public func count(of level: LogLevel) -> Int {
        countsByLevel[level, default: 0]
    }

    /// Share of all entries at `level`, from 0 to 1.
    public func fraction(of level: LogLevel) -> Double {
        total == 0 ? 0 : Double(count(of: level)) / Double(total)
    }

    /// Errors and faults: what "only problems" filters and badges care about.
    public var problemCount: Int {
        count(of: .error) + count(of: .fault)
    }
}
