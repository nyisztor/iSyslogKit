import Foundation
import Testing
@testable import iSyslogKit

/// Uses a pipe as a stand-in for stdout, so the test runner's own output is left alone.
struct StandardStreamCaptureTests {
    @Test func reportsCompleteLinesAndStillWritesToTheOriginalDestination() async throws {
        var target: [Int32] = [0, 0]
        #expect(pipe(&target) == 0)
        let (destinationRead, fakeStdout) = (target[0], target[1])

        let capture = StandardStreamCapture(fileDescriptor: fakeStdout)
        let lines = try capture.start()

        func send(_ s: String) { _ = s.withCString { write(fakeStdout, $0, strlen($0)) } }
        send("one\ntwo\npart")
        send("ial line ✓\n")
        send("no newline at the end")
        capture.stop()

        var received: [String] = []
        for await batch in lines { received += batch.map(\.text) }
        #expect(received == ["one", "two", "partial line ✓", "no newline at the end"])

        // The original destination got every byte, unchanged.
        close(fakeStdout)
        var bytes: [UInt8] = []
        var chunk = [UInt8](repeating: 0, count: 256)
        while case let n = read(destinationRead, &chunk, chunk.count), n > 0 { bytes += chunk[0..<n] }
        close(destinationRead)
        #expect(String(decoding: bytes, as: UTF8.self) == "one\ntwo\npartial line ✓\nno newline at the end")
    }

    @Test func splitsOverlongLines() async throws {
        var target: [Int32] = [0, 0]
        #expect(pipe(&target) == 0)
        let capture = StandardStreamCapture(fileDescriptor: target[1])
        let lines = try capture.start()

        // Drain the original destination so the tee never blocks on a full pipe.
        let destination = target[0]
        let drain = Thread { var buf = [UInt8](repeating: 0, count: 4096); while read(destination, &buf, buf.count) > 0 {} }
        drain.start()

        let long = String(repeating: "x", count: StandardStreamCapture.maxLineLength + 10) + "\n"
        _ = long.withCString { write(target[1], $0, strlen($0)) }
        capture.stop()
        close(target[1])

        var received: [String] = []
        for await batch in lines { received += batch.map(\.text) }
        #expect(received.joined().count == StandardStreamCapture.maxLineLength + 10)
        #expect(received.allSatisfy { $0.count <= StandardStreamCapture.maxLineLength })
    }
}
