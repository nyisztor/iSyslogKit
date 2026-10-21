import SwiftUI
import iSyslogKit

struct LogEntryDetailView: View {
    let entry: LogEntry

    var body: some View {
        List {
            Section {
                Text(entry.message)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } header: {
                Label(entry.level.title, systemImage: entry.level.symbol)
                    .foregroundStyle(entry.level.color)
                    .font(.subheadline.weight(.semibold))
                    .textCase(nil)
            }

            Section("Details") {
                row("Time", entry.date.formatted(.dateTime.year().month().day().hour().minute().second().secondFraction(.fractional(3))))
                row("Subsystem", entry.subsystem)
                row("Category", entry.category)
                row("Process", entry.process.isEmpty ? "" : "\(entry.process) (\(entry.processID))")
                row("Thread", entry.threadID == 0 ? "" : "0x" + String(entry.threadID, radix: 16))
                row("Library", entry.sender)
                row("Source", sourceName)
            }
        }
        .navigationTitle(entry.level.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: entry.plainText)
            }
        }
    }

    @ViewBuilder
    private func row(_ title: String, _ value: String) -> some View {
        if !value.isEmpty {
            LabeledContent(title) {
                Text(value).textSelection(.enabled)
            }
        }
    }

    private var sourceName: String {
        switch entry.origin {
        case .osLog: "Unified log"
        case .standardOutput: "Standard output"
        case .standardError: "Standard error"
        case .direct: "iSyslogKit"
        }
    }
}
