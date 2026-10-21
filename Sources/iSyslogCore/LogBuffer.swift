/// Keeps the most recent entries up to a fixed capacity, oldest first.
public struct LogBuffer: Sendable {
    public let capacity: Int
    public private(set) var entries: [LogEntry] = []
    /// How many entries were dropped to stay within `capacity`.
    public private(set) var droppedCount = 0

    public init(capacity: Int) {
        precondition(capacity > 0, "LogBuffer capacity must be positive")
        self.capacity = capacity
    }

    /// Adds entries (sorted by date) in date order, dropping the oldest when full.
    public mutating func append<S: Sequence>(contentsOf newEntries: S) where S.Element == LogEntry {
        entries = entries.mergingChronologically(Array(newEntries))
        let overflow = entries.count - capacity
        if overflow > 0 {
            entries.removeFirst(overflow)
            droppedCount += overflow
        }
    }

    public mutating func removeAll() {
        entries.removeAll()
        droppedCount = 0
    }
}

extension Array where Element == LogEntry {
    /// Merges `newEntries` into this array; both must be sorted by date. Entries with equal
    /// dates keep their arrival order (existing ones first).
    ///
    /// Batches arrive out of order relative to each other: printed lines are captured
    /// instantly, unified-log entries only when the next query runs.
    public func mergingChronologically(_ newEntries: [LogEntry]) -> [LogEntry] {
        guard let firstNew = newEntries.first else { return self }
        if let last = self.last, last.date > firstNew.date {
            var merged: [LogEntry] = []
            merged.reserveCapacity(count + newEntries.count)
            var i = startIndex
            var j = newEntries.startIndex
            while i < endIndex, j < newEntries.endIndex {
                if self[i].date <= newEntries[j].date {
                    merged.append(self[i])
                    i += 1
                } else {
                    merged.append(newEntries[j])
                    j += 1
                }
            }
            merged.append(contentsOf: self[i...])
            merged.append(contentsOf: newEntries[j...])
            return merged
        }
        return self + newEntries
    }
}
