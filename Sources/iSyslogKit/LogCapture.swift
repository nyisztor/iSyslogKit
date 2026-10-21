import Foundation
import iSyslogCore

/// Collects the app's log entries into a buffer, on demand or by polling.
///
/// Queries are slow (about 1.5 s on device), so they run on a private serial queue and
/// concurrent `refresh()` calls share one query instead of stacking up.
public actor LogCapture {
    public nonisolated let configuration: ISyslog.Configuration

    private var buffer: LogBuffer
    private let source = OSLogStoreSource()
    private let queue = DispatchQueue(label: "iSyslogKit.capture", qos: .utility)
    private var inFlight: Task<[LogEntry], Error>?
    private var pollingTask: Task<Void, Never>?
    private var subscribers: [UUID: AsyncStream<[LogEntry]>.Continuation] = [:]
    /// Started synchronously from any thread, so guarded by a lock rather than the actor.
    private nonisolated let streamCaptures = LockedCaptures()

    public init(configuration: ISyslog.Configuration = .init()) {
        self.configuration = configuration
        self.buffer = LogBuffer(capacity: configuration.bufferCapacity)
    }

    /// Everything captured so far, oldest first.
    public var entries: [LogEntry] { buffer.entries }

    /// Entries dropped because the buffer was full.
    public var droppedCount: Int { buffer.droppedCount }

    public var isPolling: Bool { pollingTask != nil }

    /// Reads new entries from the log, adds them to the buffer and returns them.
    @discardableResult
    public func refresh() async throws -> [LogEntry] {
        if let inFlight {
            // Someone else's query is running; once it finishes, its entries are in the buffer.
            _ = try await inFlight.value
            return []
        }
        let source = self.source
        let queue = self.queue
        // The task adds the entries itself (it runs on this actor), so anyone awaiting it sees
        // them in the buffer as soon as it completes. Ingesting after `await task.value` instead
        // let a waiting caller (e.g. an export) resume first and read a buffer without them.
        let task = Task<[LogEntry], Error> {
            let fetched = try await withCheckedThrowingContinuation { continuation in
                queue.async {
                    continuation.resume(with: Result { try source.fetchNewEntries() })
                }
            }
            self.ingest(fetched)
            return fetched
        }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }

    /// Adds entries (sorted by date) from any source and tells subscribers.
    func ingest(_ newEntries: [LogEntry]) {
        guard !newEntries.isEmpty else { return }
        buffer.append(contentsOf: newEntries)
        for subscriber in subscribers.values { subscriber.yield(newEntries) }
    }

    /// Starts capturing `print` output (and stderr, if configured) as entries.
    /// Redirecting the process's streams is global, so `ISyslog.start()` does this once.
    ///
    /// Synchronous on purpose: the redirect is in place when this returns, so lines printed right
    /// after `ISyslog.start()` (typically during launch) aren't missed.
    public nonisolated func startCapturingStandardStreams() {
        guard streamCaptures.claimStart() else { return }
        var streams: [(Int32, LogEntry.Origin)] = []
        if configuration.capturesStandardOutput {
            // A pipe makes stdout fully buffered (4 KB); line buffering delivers each print right away.
            fflush(stdout)
            setvbuf(stdout, nil, _IOLBF, 0)
            streams.append((STDOUT_FILENO, .standardOutput))
        }
        if configuration.capturesStandardError {
            streams.append((STDERR_FILENO, .standardError))
        }

        let process = ProcessInfo.processInfo
        for (fd, origin) in streams {
            let capture = StandardStreamCapture(fileDescriptor: fd)
            guard let lines = try? capture.start() else { continue }
            streamCaptures.add(capture)
            let category = origin == .standardOutput ? "stdout" : "stderr"
            Task { [weak self] in
                for await batch in lines {
                    let entries = batch.map {
                        LogEntry(date: $0.date, level: .notice, message: $0.text, category: category,
                                 process: process.processName, processID: process.processIdentifier,
                                 sender: process.processName, origin: origin)
                    }
                    await self?.ingest(entries)
                }
            }
        }
    }

    /// Restores the original streams. Mostly for tests.
    nonisolated func stopCapturingStandardStreams() {
        streamCaptures.stopAll()
    }

    /// Everything captured so far plus a stream of the batches that follow, taken in one step
    /// so no batch is missed or delivered twice. The stream ends when the caller stops iterating.
    public func subscribe() -> (entries: [LogEntry], updates: AsyncStream<[LogEntry]>) {
        let id = UUID()
        let (stream, continuation) = AsyncStream<[LogEntry]>.makeStream(bufferingPolicy: .bufferingNewest(32))
        subscribers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeSubscriber(id) }
        }
        return (buffer.entries, stream)
    }

    /// Refreshes every `configuration.pollInterval` until `stopPolling()`.
    /// Consoles poll while visible; nothing polls in the background by default.
    public func startPolling() {
        guard pollingTask == nil else { return }
        let interval = configuration.pollInterval
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                _ = try? await self?.refresh()
                try? await Task.sleep(for: interval)
            }
        }
    }

    public func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// Forgets everything captured so far. Entries already in the log aren't re-read.
    public func clear() {
        buffer.removeAll()
    }

    /// Refreshes, then writes the matching entries to a `.isyslog` file for sharing.
    /// - Returns: The file's URL in the temporary directory.
    public func exportSession(filter: LogFilter = .everything) async throws -> URL {
        try await refresh()
        return try Session(metadata: .current(), entries: filter.apply(to: buffer.entries)).writeToTemporaryFile()
    }

    private func removeSubscriber(_ id: UUID) {
        subscribers[id] = nil
    }
}

/// The stream captures of one `LogCapture`, safe to start and stop from any thread.
final class LockedCaptures: @unchecked Sendable {
    private let lock = NSLock()
    private var started = false
    private var captures: [StandardStreamCapture] = []

    /// True for the first caller only.
    func claimStart() -> Bool {
        lock.withLock {
            defer { started = true }
            return !started
        }
    }

    func add(_ capture: StandardStreamCapture) {
        lock.withLock { captures.append(capture) }
    }

    func stopAll() {
        let stopping = lock.withLock {
            defer { captures.removeAll(); started = false }
            return captures
        }
        for capture in stopping { capture.stop() }
    }
}
