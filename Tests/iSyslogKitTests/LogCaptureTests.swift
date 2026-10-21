import Foundation
import OSLog
import Testing
@testable import iSyslogKit

/// Runs against the real unified log of the test process, so each refresh takes about a second.
@Suite(.serialized)
struct LogCaptureTests {
    let logger = Logger(subsystem: "com.isyslog.tests", category: "capture")

    @Test func capturesOwnLogMessagesOnce() async throws {
        let capture = LogCapture(configuration: .init(activation: .always))
        let marker = "marker-\(UUID().uuidString)"
        logger.error("\(marker, privacy: .public)")

        let first = try await capture.refresh()
        let hit = try #require(first.first { $0.message == marker })
        #expect(hit.level == .error)
        #expect(hit.subsystem == "com.isyslog.tests")
        #expect(hit.category == "capture")
        #expect(hit.processID == ProcessInfo.processInfo.processIdentifier)

        let second = try await capture.refresh()
        #expect(!second.contains { $0.message == marker })
        #expect(await capture.entries.filter { $0.message == marker }.count == 1)
    }

    @Test func concurrentRefreshesShareOneQuery() async throws {
        let capture = LogCapture(configuration: .init(activation: .always))
        let marker = "concurrent-\(UUID().uuidString)"
        logger.notice("\(marker, privacy: .public)")

        async let a = capture.refresh()
        async let b = capture.refresh()
        let total = try await (a + b).filter { $0.message == marker }.count

        #expect(total == 1)
        #expect(await capture.entries.filter { $0.message == marker }.count == 1)
    }

    @Test func exportDuringAnotherRefreshIncludesItsEntries() async throws {
        // An export started while the console's first refresh is still running waits for that
        // query; the exported file must contain what the query found.
        for _ in 0..<3 {
            let capture = LogCapture(configuration: .init(activation: .always))
            let marker = "racing-\(UUID().uuidString)"
            logger.notice("\(marker, privacy: .public)")

            async let consoleRefresh = capture.refresh()
            try await Task.sleep(for: .milliseconds(20))
            let url = try await capture.exportSession()
            defer { try? FileManager.default.removeItem(at: url) }
            _ = try await consoleRefresh

            let session = try Session(decoding: Data(contentsOf: url))
            #expect(session.entries.contains { $0.message == marker })
        }
    }

    @Test func subscriptionGivesSnapshotThenNewBatches() async throws {
        let capture = LogCapture(configuration: .init(activation: .always))
        let before = "before-\(UUID().uuidString)"
        logger.notice("\(before, privacy: .public)")
        try await capture.refresh()

        let (snapshot, updates) = await capture.subscribe()
        #expect(snapshot.contains { $0.message == before })

        let after = "after-\(UUID().uuidString)"
        logger.notice("\(after, privacy: .public)")
        try await capture.refresh()

        var iterator = updates.makeAsyncIterator()
        let batch = try #require(await iterator.next())
        #expect(batch.contains { $0.message == after })
        #expect(!batch.contains { $0.message == before })
    }

    @Test func exportWritesADecodableSession() async throws {
        let capture = LogCapture(configuration: .init(activation: .always))
        let marker = "export-\(UUID().uuidString)"
        logger.fault("\(marker, privacy: .public)")

        let url = try await capture.exportSession()
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(url.pathExtension == Session.fileExtension)
        let session = try Session(decoding: Data(contentsOf: url))
        #expect(session.entries.contains { $0.message == marker && $0.level == .fault })
        #expect(session.metadata.kitVersion == ISyslog.version)
        #if os(macOS)
        #expect(session.metadata.systemName == "macOS")
        // Real Macs report e.g. "Mac17,2"; virtual machines (like CI runners) "VirtualMac2,1".
        #expect(session.metadata.deviceModel.contains("Mac"))
        #else
        #expect(["iOS", "iPadOS"].contains(session.metadata.systemName))
        #expect(session.metadata.deviceModel.hasPrefix("iPhone") || session.metadata.deviceModel.hasPrefix("iPad"))
        #endif
    }

    @Test func bufferCapacityIsRespected() async throws {
        let capture = LogCapture(configuration: .init(activation: .always, bufferCapacity: 5))
        for i in 0..<20 { logger.notice("bulk \(i, privacy: .public)") }

        try await capture.refresh()
        #expect(await capture.entries.count == 5)
        #expect(await capture.droppedCount > 0)
    }
}
