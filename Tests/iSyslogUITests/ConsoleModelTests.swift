import Foundation
import Testing
@testable import iSyslogUI

@MainActor
struct ConsoleModelTests {
    static func entry(_ t: Double, _ level: LogLevel, _ message: String, subsystem: String = "com.example.demo") -> LogEntry {
        LogEntry(date: Date(timeIntervalSince1970: t), level: level, message: message, subsystem: subsystem)
    }

    static let session = Session(
        metadata: .init(appName: "Demo", appVersion: "1", appBuild: "1", bundleID: "com.example.demo",
                        deviceModel: "iPad8,1", systemName: "iPadOS", systemVersion: "26.7.1",
                        createdAt: Date(timeIntervalSince1970: 0), kitVersion: "0.1.0"),
        entries: [
            entry(1, .info, "started"),
            entry(2, .error, "upload failed"),
            entry(3, .notice, "scene active", subsystem: "com.apple.UIKit"),
            entry(4, .fault, "database corrupt", subsystem: "com.example.storage"),
        ]
    )

    @Test func showsNewestFirstWithoutSystemMessages() async {
        let model = ConsoleModel(session: Self.session)
        await model.appear()

        #expect(model.title == "Demo")
        #expect(model.visibleEntries.map(\.message) == ["database corrupt", "upload failed", "started"])
        #expect(model.subsystems == ["com.example.demo", "com.example.storage"])
    }

    @Test func levelTogglesHideEntriesButKeepStatistics() async {
        let model = ConsoleModel(session: Self.session)
        await model.appear()

        model.toggle(.info)
        #expect(model.visibleEntries.map(\.message) == ["database corrupt", "upload failed"])
        #expect(model.statistics.total == 3)
        #expect(model.statistics.count(of: .info) == 1)
        #expect(model.hasActiveFilter)

        model.showsOnlyProblems = true
        #expect(model.visibleEntries.allSatisfy { $0.level >= .error })
        model.resetFilters()
        #expect(model.visibleEntries.count == 3)
        #expect(!model.hasActiveFilter)
    }

    @Test func searchAndSystemMessagesCombine() async {
        let model = ConsoleModel(session: Self.session)
        await model.appear()

        model.filter.includesSystemMessages = true
        #expect(model.visibleEntries.count == 4)
        #expect(model.subsystems.contains("com.apple.UIKit"))

        model.filter.searchText = "SCENE"
        #expect(model.visibleEntries.map(\.message) == ["scene active"])
        // Search alone isn't a "filter" (it has its own field); showing system messages is.
        #expect(model.hasActiveFilter)
        model.filter.includesSystemMessages = false
        #expect(!model.hasActiveFilter)
    }

    @Test func sessionFileRoundTrips() async throws {
        let model = ConsoleModel(session: Self.session)
        let url = try await model.makeSessionFile()
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(url.pathExtension == "isyslog")
        #expect(try Session(decoding: Data(contentsOf: url)).entries.count == 4)
    }
}
