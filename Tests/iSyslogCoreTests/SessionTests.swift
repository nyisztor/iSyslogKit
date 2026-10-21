import Foundation
import Testing
@testable import iSyslogCore

struct SessionTests {
    static let metadata = Session.Metadata(
        appName: "Demo",
        appVersion: "1.2",
        appBuild: "42",
        bundleID: "com.example.demo",
        deviceModel: "iPhone16,1",
        systemName: "iOS",
        systemVersion: "27.0.1",
        createdAt: Date(timeIntervalSince1970: 1_792_579_892.5),
        kitVersion: "0.1.0"
    )

    @Test func roundTripPreservesEverything() throws {
        let entries = [
            LogEntry(date: Date(timeIntervalSince1970: 1_792_579_890.123456), level: .error, message: "Upload failed: ✗ timeout",
                     subsystem: "com.example.demo", category: "network", process: "Demo", processID: 812,
                     threadID: 0x1d635, sender: "Demo", origin: .osLog),
            LogEntry(date: Date(timeIntervalSince1970: 1_792_579_891), level: .debug, message: "tap", origin: .direct),
        ]
        let session = Session(metadata: Self.metadata, entries: entries)

        let decoded = try Session(decoding: session.encoded())

        #expect(decoded.metadata == session.metadata)
        #expect(decoded.entries.count == 2)
        for (a, b) in zip(decoded.entries, entries) {
            #expect(a.id == b.id)
            #expect(a.message == b.message)
            #expect(a.level == b.level)
            #expect(abs(a.date.timeIntervalSince(b.date)) < 1e-6)
        }
    }

    @Test func levelsAreWrittenByName() throws {
        let session = Session(metadata: Self.metadata, entries: [LogEntry(date: .now, level: .fault, message: "x")])
        let json = try #require(String(data: session.encoded(), encoding: .utf8))
        #expect(json.contains(#""level":"fault""#))
    }

    @Test func newerFormatVersionIsRejected() throws {
        var json = try JSONSerialization.jsonObject(with: Session(metadata: Self.metadata, entries: []).encoded()) as! [String: Any]
        json["formatVersion"] = Session.currentFormatVersion + 1
        let data = try JSONSerialization.data(withJSONObject: json)

        #expect(throws: Session.FileError.unsupportedFormatVersion(Session.currentFormatVersion + 1)) {
            try Session(decoding: data)
        }
    }

    @Test func unknownFieldsAreIgnored() throws {
        let entry = LogEntry(date: .now, level: .info, message: "hello")
        var json = try JSONSerialization.jsonObject(with: Session(metadata: Self.metadata, entries: [entry]).encoded()) as! [String: Any]
        json["networkRequests"] = [["url": "https://example.com"]]
        var entries = json["entries"] as! [[String: Any]]
        entries[0]["proOnlyField"] = 7
        json["entries"] = entries
        let data = try JSONSerialization.data(withJSONObject: json)

        let decoded = try Session(decoding: data)
        #expect(decoded.entries.first?.message == "hello")
    }

    @Test func dateRangeSpansEntries() {
        let a = Date(timeIntervalSince1970: 100), b = Date(timeIntervalSince1970: 200)
        let session = Session(metadata: Self.metadata, entries: [
            LogEntry(date: a, level: .info, message: "a"),
            LogEntry(date: b, level: .info, message: "b"),
        ])
        #expect(session.dateRange == a...b)
        #expect(Session(metadata: Self.metadata, entries: []).dateRange == nil)
    }
}
