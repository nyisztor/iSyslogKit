import Foundation
import Testing
@testable import iSyslogCore

struct LogLevelTests {
    @Test func ordersBySeverity() {
        #expect(LogLevel.allCases.sorted() == [.debug, .info, .notice, .error, .fault])
        #expect(LogLevel.error > .notice)
    }
}

struct LogFilterTests {
    let app = LogEntry(date: Date(timeIntervalSince1970: 100), level: .error, message: "Upload failed",
                       subsystem: "com.example.demo", category: "Network")
    let appDebug = LogEntry(date: Date(timeIntervalSince1970: 150), level: .debug, message: "Résumé loaded",
                            subsystem: "com.example.demo", category: "UI")
    let system = LogEntry(date: Date(timeIntervalSince1970: 200), level: .info, message: "Scene activated",
                          subsystem: "com.apple.UIKit", category: "Scene")
    let unlabeled = LogEntry(date: Date(timeIntervalSince1970: 250), level: .notice, message: "legacy log",
                             process: "Demo", sender: "Demo")
    let systemWithoutSubsystem = LogEntry(date: Date(timeIntervalSince1970: 260), level: .error,
                                          message: "fopen failed for data file", process: "Demo", sender: "libicucore.A.dylib")

    var all: [LogEntry] { [app, appDebug, system, unlabeled, systemWithoutSubsystem] }

    @Test func defaultHidesOnlySystemMessages() {
        #expect(LogFilter().apply(to: all) == [app, appDebug, unlabeled])
        #expect(LogFilter.everything.apply(to: all) == all)
    }

    @Test func systemMessagesAreRecognizedWithOrWithoutSubsystem() {
        #expect(system.isSystemMessage)
        #expect(systemWithoutSubsystem.isSystemMessage)
        #expect(!app.isSystemMessage)
        #expect(!unlabeled.isSystemMessage)
    }

    @Test func filtersByLevel() {
        let problems = LogFilter(levels: [.error, .fault])
        #expect(problems.apply(to: all) == [app])
    }

    @Test func searchIsCaseAndDiacriticInsensitiveAcrossFields() {
        #expect(LogFilter(searchText: "upload").apply(to: all) == [app])
        #expect(LogFilter(searchText: "resume").apply(to: all) == [appDebug])
        #expect(LogFilter(searchText: "network").apply(to: all) == [app])
        #expect(LogFilter(searchText: "example").apply(to: all) == [app, appDebug])
        #expect(LogFilter(searchText: "   ").apply(to: all) == [app, appDebug, unlabeled])
    }

    @Test func filtersBySubsystemCategoryAndDate() {
        #expect(LogFilter(subsystems: ["com.apple.UIKit"], includesSystemMessages: true).apply(to: all) == [system])
        #expect(LogFilter(categories: ["UI"]).apply(to: all) == [appDebug])
        let range = Date(timeIntervalSince1970: 120)...Date(timeIntervalSince1970: 260)
        #expect(LogFilter(dateRange: range).apply(to: all) == [appDebug, unlabeled])
    }
}

struct LogStatisticsTests {
    @Test func countsLevelsAndSubsystems() {
        let entries = [LogLevel.error, .error, .fault, .info].map {
            LogEntry(date: .now, level: $0, message: "", subsystem: $0 == .info ? "b" : "a")
        }
        let stats = LogStatistics(entries)

        #expect(stats.total == 4)
        #expect(stats.count(of: .error) == 2)
        #expect(stats.count(of: .debug) == 0)
        #expect(stats.fraction(of: .error) == 0.5)
        #expect(stats.problemCount == 3)
        #expect(stats.countsBySubsystem == ["a": 3, "b": 1])
        #expect(LogStatistics([]).fraction(of: .error) == 0)
    }
}

struct LogBufferTests {
    @Test func dropsOldestBeyondCapacity() {
        var buffer = LogBuffer(capacity: 3)
        let entries = (0..<5).map { LogEntry(date: Date(timeIntervalSince1970: Double($0)), level: .info, message: "\($0)") }

        buffer.append(contentsOf: entries.prefix(2))
        #expect(buffer.entries.map(\.message) == ["0", "1"])

        buffer.append(contentsOf: entries.dropFirst(2))
        #expect(buffer.entries.map(\.message) == ["2", "3", "4"])
        #expect(buffer.droppedCount == 2)

        buffer.removeAll()
        #expect(buffer.entries.isEmpty)
        #expect(buffer.droppedCount == 0)
    }

    @Test func mergesOlderBatchesInDateOrder() {
        func e(_ t: Double, _ m: String) -> LogEntry { LogEntry(date: Date(timeIntervalSince1970: t), level: .info, message: m) }
        // Printed lines arrive first; a log query later delivers older entries.
        var buffer = LogBuffer(capacity: 4)
        buffer.append(contentsOf: [e(2, "print a"), e(5, "print b")])
        buffer.append(contentsOf: [e(1, "log 1"), e(2, "log 2"), e(3, "log 3")])

        #expect(buffer.entries.map(\.message) == ["print a", "log 2", "log 3", "print b"])
        #expect(buffer.droppedCount == 1)  // "log 1", the oldest
    }

    @Test func mergeKeepsArrivalOrderForEqualDatesAndFastPathAppends() {
        func e(_ t: Double, _ m: String) -> LogEntry { LogEntry(date: Date(timeIntervalSince1970: t), level: .info, message: m) }
        #expect([e(1, "a"), e(2, "b")].mergingChronologically([e(2, "c"), e(3, "d")]).map(\.message) == ["a", "b", "c", "d"])
        #expect([e(1, "a"), e(3, "b")].mergingChronologically([e(1, "x"), e(2, "y")]).map(\.message) == ["a", "x", "y", "b"])
        #expect([LogEntry]().mergingChronologically([e(1, "a")]).map(\.message) == ["a"])
    }
}
