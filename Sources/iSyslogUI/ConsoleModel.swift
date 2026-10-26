import Foundation
import Observation
import iSyslogKit

/// State behind a log console: the entries, the active filter, and what's derived from them.
/// Works with a live capture (inside the app being debugged) or a fixed session (an opened file).
@MainActor
@Observable
public final class ConsoleModel {
    public enum Source: Sendable {
        case live(LogCapture)
        case session(Session)
    }

    public let source: Source

    public var filter = LogFilter() {
        didSet { recompute() }
    }

    /// Whether a visible live console keeps polling for new entries.
    public var isLive = true {
        didSet { updatePolling() }
    }

    /// All entries, oldest first.
    public private(set) var entries: [LogEntry] = [] {
        didSet { recompute() }
    }

    /// Entries passing the filter, newest first.
    public private(set) var visibleEntries: [LogEntry] = []

    /// Counts over entries that pass every filter except the level filter, so the chart keeps
    /// its shape (and shows what's hidden) while levels are toggled.
    public private(set) var statistics = LogStatistics([])

    /// Subsystems present in the entries the system-message setting allows, for the filter menu.
    public private(set) var subsystems: [String] = []

    public private(set) var isRefreshing = false
    public private(set) var lastError: String?

    private var isVisible = false
    private var updatesTask: Task<Void, Never>?

    public init(source: Source) {
        self.source = source
    }

    public convenience init(capture: LogCapture) {
        self.init(source: .live(capture))
    }

    public convenience init(session: Session) {
        self.init(source: .session(session))
    }

    public var title: String {
        switch source {
        case .live: "Logs"
        case .session(let session): session.metadata.appName
        }
    }

    public var isLiveSource: Bool {
        if case .live = source { true } else { false }
    }

    public var hasActiveFilter: Bool {
        var unfiltered = LogFilter()
        unfiltered.searchText = filter.searchText
        return filter != unfiltered
    }

    // MARK: Lifecycle

    public func appear() async {
        isVisible = true
        switch source {
        case .session(let session):
            if entries.isEmpty { entries = session.entries }
        case .live(let capture):
            let (current, updates) = await capture.subscribe()
            entries = current
            follow(updates, capacity: capture.configuration.bufferCapacity)
            // Load right away (with a visible spinner) rather than waiting for the first poll.
            await refresh()
            updatePolling()
        }
    }

    public func disappear() {
        isVisible = false
        updatesTask?.cancel()
        updatesTask = nil
        updatePolling()
    }

    public func refresh() async {
        guard case .live(let capture) = source else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            try await capture.refresh()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    public func clear() async {
        guard case .live(let capture) = source else { return }
        await capture.clear()
        entries = []
    }

    // MARK: Filtering

    public func isShowing(_ level: LogLevel) -> Bool {
        filter.levels.contains(level)
    }

    public func toggle(_ level: LogLevel) {
        if filter.levels.contains(level) {
            filter.levels.remove(level)
        } else {
            filter.levels.insert(level)
        }
    }

    public var showsOnlyProblems: Bool {
        get { filter.levels == [.error, .fault] }
        set { filter.levels = newValue ? [.error, .fault] : Set(LogLevel.allCases) }
    }

    public func resetFilters() {
        filter = LogFilter(searchText: filter.searchText)
    }

    // MARK: Sharing

    /// Makes a `.isyslog` file with everything captured, regardless of the filter.
    public func makeSessionFile() async throws -> URL {
        switch source {
        case .live(let capture): try await capture.exportSession()
        case .session(let session): try session.writeToTemporaryFile()
        }
    }

    // MARK: Private

    private func follow(_ updates: AsyncStream<LogCapture.Update>, capacity: Int) {
        updatesTask?.cancel()
        updatesTask = Task { [weak self] in
            for await update in updates {
                guard let self else { return }
                // After falling behind, the capture resends everything rather than the lost batches.
                if update.replacesEarlierEntries {
                    self.entries = update.entries
                    continue
                }
                var updated = self.entries.mergingChronologically(update.entries)
                if updated.count > capacity { updated.removeFirst(updated.count - capacity) }
                self.entries = updated
            }
        }
    }

    private func updatePolling() {
        guard case .live(let capture) = source else { return }
        let shouldPoll = isVisible && isLive
        Task { shouldPoll ? await capture.startPolling() : await capture.stopPolling() }
    }

    private func recompute() {
        var ignoringLevels = filter
        ignoringLevels.levels = Set(LogLevel.allCases)
        let candidates = ignoringLevels.apply(to: entries)

        statistics = LogStatistics(candidates)
        visibleEntries = candidates.reversed().filter { filter.levels.contains($0.level) }
        subsystems = Set(entries.lazy
            .filter { self.filter.includesSystemMessages || !$0.isSystemMessage }
            .map(\.subsystem)
            .filter { !$0.isEmpty })
            .sorted()
    }
}
