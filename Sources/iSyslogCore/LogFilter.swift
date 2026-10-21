import Foundation

/// What a console shows. The default shows every level of the app's own messages.
public struct LogFilter: Hashable, Sendable {
    public var levels: Set<LogLevel>
    /// Matched case-insensitively against message, subsystem and category. Empty matches everything.
    public var searchText: String
    /// Empty means all subsystems.
    public var subsystems: Set<String>
    /// Empty means all categories.
    public var categories: Set<String>
    public var includesSystemMessages: Bool
    public var dateRange: ClosedRange<Date>?

    public init(
        levels: Set<LogLevel> = Set(LogLevel.allCases),
        searchText: String = "",
        subsystems: Set<String> = [],
        categories: Set<String> = [],
        includesSystemMessages: Bool = false,
        dateRange: ClosedRange<Date>? = nil
    ) {
        self.levels = levels
        self.searchText = searchText
        self.subsystems = subsystems
        self.categories = categories
        self.includesSystemMessages = includesSystemMessages
        self.dateRange = dateRange
    }

    /// Everything, including Apple framework messages.
    public static let everything = LogFilter(includesSystemMessages: true)

    public func matches(_ entry: LogEntry) -> Bool {
        guard levels.contains(entry.level) else { return false }
        guard includesSystemMessages || !entry.isSystemMessage else { return false }
        guard subsystems.isEmpty || subsystems.contains(entry.subsystem) else { return false }
        guard categories.isEmpty || categories.contains(entry.category) else { return false }
        if let dateRange, !dateRange.contains(entry.date) { return false }

        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return [entry.message, entry.subsystem, entry.category].contains {
            $0.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    public func apply<S: Sequence>(to entries: S) -> [LogEntry] where S.Element == LogEntry {
        entries.filter(matches)
    }
}
