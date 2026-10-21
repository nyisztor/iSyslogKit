import SwiftUI
import iSyslogKit

/// How each level looks. Severity is always shown with a symbol and a word, never color alone.
extension LogLevel {
    var title: String {
        switch self {
        case .debug: "Debug"
        case .info: "Info"
        case .notice: "Notice"
        case .error: "Error"
        case .fault: "Fault"
        }
    }

    var color: Color {
        switch self {
        case .debug: .gray
        case .info: .blue
        case .notice: .green
        case .error: .orange
        case .fault: .red
        }
    }

    var symbol: String {
        switch self {
        case .debug: "ant.fill"
        case .info: "info.circle.fill"
        case .notice: "bell.fill"
        case .error: "exclamationmark.triangle.fill"
        case .fault: "xmark.octagon.fill"
        }
    }
}

extension LogEntry {
    /// "subsystem · category", or whichever of the two is set.
    var sourceLabel: String {
        [subsystem, category].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var timeLabel: String {
        date.formatted(.dateTime.hour().minute().second().secondFraction(.fractional(3)))
    }

    /// One entry as plain text, for copying and sharing.
    var plainText: String {
        let source = sourceLabel.isEmpty ? "" : " [\(sourceLabel)]"
        return "\(date.formatted(.iso8601.time(includingFractionalSeconds: true))) \(level.title.uppercased())\(source) \(message)"
    }
}
