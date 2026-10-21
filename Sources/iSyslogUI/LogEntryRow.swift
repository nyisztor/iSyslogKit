import SwiftUI
import iSyslogKit

struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Capsule()
                .fill(entry.level.color)
                .frame(width: 4)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Image(systemName: entry.level.symbol)
                        .imageScale(.small)
                    Text(entry.level.title)
                        .fontWeight(.semibold)
                    Spacer(minLength: 8)
                    Text(entry.timeLabel)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
                .foregroundStyle(entry.level.color)

                Text(entry.message)
                    .font(.callout)
                    .lineLimit(4)

                if !entry.sourceLabel.isEmpty {
                    Text(entry.sourceLabel)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
