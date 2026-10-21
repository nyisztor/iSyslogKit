import Charts
import SwiftUI
import iSyslogKit

/// Donut chart of entries by level, next to one toggle per level that shows or hides it.
struct SeveritySummaryView: View {
    let statistics: LogStatistics
    let isShowing: (LogLevel) -> Bool
    let toggle: (LogLevel) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            donut
            VStack(spacing: 2) {
                ForEach(LogLevel.allCases.reversed(), id: \.self) { level in
                    levelToggle(level)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var donut: some View {
        let levels = LogLevel.allCases.filter { statistics.count(of: $0) > 0 }
        return ZStack {
            if levels.isEmpty {
                Circle()
                    .stroke(.quaternary, lineWidth: 16)
                    .padding(8)
            } else {
                Chart(levels, id: \.self) { level in
                    SectorMark(
                        angle: .value("Entries", statistics.count(of: level)),
                        innerRadius: .ratio(0.64),
                        angularInset: 1.5
                    )
                    .cornerRadius(3)
                    .foregroundStyle(level.color.opacity(isShowing(level) ? 1 : 0.22))
                }
                .chartLegend(.hidden)
            }
            VStack(spacing: 0) {
                Text(statistics.total, format: .number.notation(.compactName))
                    .font(.title3.weight(.semibold).monospacedDigit())
                Text("entries")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 104, height: 104)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Entries by level")
        .accessibilityValue(LogLevel.allCases.reversed()
            .map { "\($0.title) \(statistics.count(of: $0))" }
            .joined(separator: ", "))
    }

    private func levelToggle(_ level: LogLevel) -> some View {
        let shown = isShowing(level)
        return Button {
            toggle(level)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: level.symbol)
                    .foregroundStyle(shown ? level.color : .secondary)
                    .frame(width: 20)
                Text(level.title)
                    .foregroundStyle(shown ? .primary : .secondary)
                    .strikethrough(!shown, color: .secondary)
                Spacer(minLength: 8)
                Text(statistics.count(of: level), format: .number)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(level.title)
        .accessibilityValue("\(statistics.count(of: level)) entries, \(shown ? "shown" : "hidden")")
        .accessibilityHint("Shows or hides \(level.title.lowercased()) entries")
        .accessibilityAddTraits(shown ? .isSelected : [])
    }
}
