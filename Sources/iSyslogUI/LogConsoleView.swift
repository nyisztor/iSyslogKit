import SwiftUI
// One `import iSyslogUI` gives apps the console plus `ISyslog.start()` and the model types.
@_exported import iSyslogKit

/// The console for the running app's own logs. Put it anywhere in your navigation, or present
/// it with `.isyslogConsole(isPresented:)`.
///
/// ```swift
/// .sheet(isPresented: $showLogs) { ISyslogConsole() }
/// ```
public struct ISyslogConsole: View {
    @Environment(\.isPresented) private var isPresented
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if let capture = ISyslog.capture {
                    LogConsoleView(model: ConsoleModel(capture: capture))
                } else {
                    ContentUnavailableView {
                        Label("Log capture is off", systemImage: "moon.zzz")
                    } description: {
                        Text("iSyslogKit captures logs in Debug and TestFlight builds. To capture in this build, start it with `ISyslog.start(.init(activation: .always))`.")
                    }
                }
            }
            .toolbar {
                if isPresented {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
    }
}

extension View {
    /// Presents the log console as a sheet.
    public func isyslogConsole(isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) {
            ISyslogConsole()
        }
    }
}

/// A searchable, filterable list of log entries with a severity summary.
/// Used by `ISyslogConsole` for live logs and by the iSyslog app for opened sessions.
public struct LogConsoleView: View {
    @State private var model: ConsoleModel

    public init(model: ConsoleModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        List {
            Section {
                SeveritySummaryView(
                    statistics: model.statistics,
                    isShowing: model.isShowing,
                    toggle: model.toggle
                )
            }

            Section {
                if model.visibleEntries.isEmpty {
                    emptyState
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(model.visibleEntries) { entry in
                        NavigationLink(value: entry) {
                            LogEntryRow(entry: entry)
                        }
                    }
                }
            } header: {
                entriesHeader
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .navigationTitle(model.title)
        .navigationDestination(for: LogEntry.self) { entry in
            LogEntryDetailView(entry: entry)
        }
        .searchable(text: $model.filter.searchText, prompt: "Search messages")
        .refreshable { await model.refresh() }
        .toolbar { toolbarContent }
        .task { await model.appear() }
        .onDisappear { model.disappear() }
    }

    // MARK: Pieces

    private var entriesHeader: some View {
        HStack {
            Text("\(model.visibleEntries.count) of \(model.statistics.total)")
                .monospacedDigit()
            Spacer()
            if model.isLiveSource {
                if model.isRefreshing {
                    ProgressView().controlSize(.mini)
                } else if model.isLive {
                    Label("Live", systemImage: "dot.radiowaves.left.and.right")
                        .foregroundStyle(.green)
                        .symbolEffect(.variableColor.iterative, options: .repeating)
                } else {
                    Label("Paused", systemImage: "pause.circle")
                }
            }
        }
        .font(.caption)
    }

    @ViewBuilder
    private var emptyState: some View {
        if model.entries.isEmpty && model.isRefreshing {
            ContentUnavailableView {
                ProgressView()
                    .controlSize(.large)
            } description: {
                Text("Reading logs…")
            }
        } else if model.entries.isEmpty {
            ContentUnavailableView(
                "No logs yet",
                systemImage: "text.alignleft",
                description: Text(model.isLiveSource
                    ? "Messages your app logs with Logger appear here."
                    : "This session contains no entries.")
            )
        } else if !model.filter.searchText.isEmpty {
            ContentUnavailableView.search(text: model.filter.searchText)
        } else {
            ContentUnavailableView {
                Label("Nothing matches", systemImage: "line.3.horizontal.decrease.circle")
            } description: {
                Text("No entries match the current filters.")
            } actions: {
                Button("Reset Filters") { model.resetFilters() }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if model.isLiveSource {
                Button {
                    model.isLive.toggle()
                } label: {
                    Label(model.isLive ? "Pause" : "Resume", systemImage: model.isLive ? "pause.fill" : "play.fill")
                }
            }

            filterMenu

            ShareSessionButton(title: "\(model.title) log session") { [model] in
                try await model.makeSessionFile()
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Toggle("Errors & Faults Only", systemImage: "exclamationmark.triangle", isOn: $model.showsOnlyProblems)
            Toggle("Apple Framework Messages", systemImage: "apple.logo", isOn: $model.filter.includesSystemMessages)

            if !model.subsystems.isEmpty {
                Picker(selection: subsystemSelection) {
                    Text("All Subsystems").tag(String?.none)
                    ForEach(model.subsystems, id: \.self) { subsystem in
                        Text(subsystem).tag(String?.some(subsystem))
                    }
                } label: {
                    Label("Subsystem", systemImage: "square.stack.3d.up")
                }
                .pickerStyle(.menu)
            }

            Section {
                Button("Reset Filters", systemImage: "arrow.counterclockwise") { model.resetFilters() }
                    .disabled(!model.hasActiveFilter)
                if model.isLiveSource {
                    Button("Clear Logs", systemImage: "trash", role: .destructive) {
                        Task { await model.clear() }
                    }
                }
            }
        } label: {
            Label("Filter", systemImage: model.hasActiveFilter
                ? "line.3.horizontal.decrease.circle.fill"
                : "line.3.horizontal.decrease.circle")
        }
    }

    /// One subsystem at a time keeps the menu simple; the model supports several.
    private var subsystemSelection: Binding<String?> {
        Binding(
            get: { model.filter.subsystems.count == 1 ? model.filter.subsystems.first : nil },
            set: { model.filter.subsystems = $0.map { [$0] } ?? [] }
        )
    }
}
