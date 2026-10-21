import Foundation

/// Tees a file descriptor (stdout or stderr) through a pipe: everything written still reaches
/// its original destination, such as Xcode's console, and complete lines are reported.
final class StandardStreamCapture: @unchecked Sendable {
    struct Line: Sendable {
        var text: String
        var date: Date
    }

    /// Longest line kept whole; longer output is split so memory stays bounded.
    static let maxLineLength = 16 * 1024

    let fileDescriptor: Int32
    private var originalFD: Int32 = -1
    private var readFD: Int32 = -1

    init(fileDescriptor: Int32) {
        self.fileDescriptor = fileDescriptor
    }

    /// Starts capturing. Each element is the lines from one read, in order.
    func start() throws -> AsyncStream<[Line]> {
        var fds: [Int32] = [0, 0]
        guard pipe(&fds) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        let original = dup(fileDescriptor)
        guard original >= 0, dup2(fds[1], fileDescriptor) >= 0 else {
            let code = POSIXErrorCode(rawValue: errno) ?? .EIO
            close(fds[0]); close(fds[1])
            if original >= 0 { close(original) }
            throw POSIXError(code)
        }
        // `fileDescriptor` now refers to the pipe's write end; this extra copy isn't needed.
        close(fds[1])
        originalFD = original
        readFD = fds[0]

        let (stream, continuation) = AsyncStream<[Line]>.makeStream()
        let readFD = self.readFD
        let thread = Thread {
            Self.readLoop(from: readFD, teeTo: original, continuation: continuation)
        }
        thread.name = "iSyslogKit.stream-\(fileDescriptor)"
        thread.qualityOfService = .utility
        thread.start()
        return stream
    }

    /// Points the descriptor back at its original destination. That closes the pipe's last
    /// writer, so the read loop sees end-of-file, delivers any partial line and finishes.
    func stop() {
        guard originalFD >= 0 else { return }
        dup2(originalFD, fileDescriptor)
        originalFD = -1
        readFD = -1
    }

    private static func readLoop(from readFD: Int32, teeTo originalFD: Int32, continuation: AsyncStream<[Line]>.Continuation) {
        var pending: [UInt8] = []
        var chunk = [UInt8](repeating: 0, count: 4096)

        while true {
            let count = chunk.withUnsafeMutableBytes { read(readFD, $0.baseAddress, $0.count) }
            if count < 0, errno == EINTR { continue }
            guard count > 0 else { break }

            chunk.withUnsafeBytes { writeFully(originalFD, $0.baseAddress!, count) }
            pending.append(contentsOf: chunk[0..<count])

            let date = Date()
            var lines: [Line] = []
            while let newline = pending.firstIndex(of: UInt8(ascii: "\n")) {
                lines.append(Line(text: String(decoding: pending[..<newline], as: UTF8.self), date: date))
                pending.removeSubrange(...newline)
            }
            if pending.count >= maxLineLength {
                lines.append(Line(text: String(decoding: pending, as: UTF8.self), date: date))
                pending.removeAll()
            }
            if !lines.isEmpty { continuation.yield(lines) }
        }

        if !pending.isEmpty {
            continuation.yield([Line(text: String(decoding: pending, as: UTF8.self), date: Date())])
        }
        continuation.finish()
        close(readFD)
        close(originalFD)
    }

    private static func writeFully(_ fd: Int32, _ bytes: UnsafeRawPointer, _ count: Int) {
        var offset = 0
        while offset < count {
            let written = write(fd, bytes + offset, count - offset)
            if written < 0, errno == EINTR { continue }
            guard written > 0 else { return }
            offset += written
        }
    }
}
