import Foundation
import Testing
@testable import iSyslogKit

struct IncrementalCursorTests {
    struct Item: Equatable { var t: Double; var name: String }

    func pass(_ cursor: inout IncrementalCursor, _ items: [Item]) -> [String] {
        cursor.newElements(in: items, date: { Date(timeIntervalSince1970: $0.t) }).map(\.name)
    }

    @Test func firstPassReturnsEverything() {
        var cursor = IncrementalCursor()
        #expect(pass(&cursor, [Item(t: 1, name: "a"), Item(t: 2, name: "b")]) == ["a", "b"])
    }

    @Test func laterPassesReturnOnlyNewEntries() {
        var cursor = IncrementalCursor()
        let a = Item(t: 1, name: "a"), b = Item(t: 2, name: "b"), c = Item(t: 3, name: "c")
        _ = pass(&cursor, [a, b])
        #expect(pass(&cursor, [a, b, c]) == ["c"])
        #expect(pass(&cursor, [a, b, c]) == [])
    }

    @Test func entriesSharingTheNewestTimestampAreNeitherLostNorRepeated() {
        var cursor = IncrementalCursor()
        let a = Item(t: 1, name: "a"), b1 = Item(t: 2, name: "b1"), b2 = Item(t: 2, name: "b2"), b3 = Item(t: 2, name: "b3")
        #expect(pass(&cursor, [a, b1]) == ["a", "b1"])
        #expect(pass(&cursor, [a, b1, b2, b3]) == ["b2", "b3"])
        #expect(pass(&cursor, [a, b1, b2, b3, Item(t: 4, name: "d")]) == ["d"])
    }

    @Test func emptyPassKeepsPosition() {
        var cursor = IncrementalCursor()
        _ = pass(&cursor, [Item(t: 1, name: "a")])
        #expect(pass(&cursor, []) == [])
        #expect(pass(&cursor, [Item(t: 1, name: "a"), Item(t: 2, name: "b")]) == ["b"])
    }

    @Test func entriesOlderThanTheCursorAreSkipped() {
        // e.g. the system dropped old entries from the front between queries.
        var cursor = IncrementalCursor()
        _ = pass(&cursor, [Item(t: 1, name: "a"), Item(t: 2, name: "b")])
        #expect(pass(&cursor, [Item(t: 2, name: "b"), Item(t: 3, name: "c")]) == ["c"])
    }
}
