import SwiftUI
import iSyslogUI

@main
struct DemoApp: App {
    init() {
        // The example captures in every build. Real apps usually keep the default
        // (`.debugAndTestFlightBuilds`) so App Store builds capture nothing.
        ISyslog.start(.init(activation: .always))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var showsLogs = false
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    action("Sign In", "person.crop.circle.badge.checkmark") { Activity.signIn() }
                    action("Sync Photos", "arrow.triangle.2.circlepath") { Activity.syncPhotos() }
                    action("Network Failure", "wifi.exclamationmark") { Activity.networkFailure() }
                    action("Database Fault", "externaldrive.badge.xmark") { Activity.databaseFault() }
                    action("Log 1,000 Messages", "text.append") { Activity.burst(count: 1_000) }
                    action("Print to Console", "terminal") { Activity.printSomething() }
                    Button {
                        Task {
                            isWorking = true
                            await Activity.realRequest()
                            isWorking = false
                        }
                    } label: {
                        Label("Real Network Request", systemImage: "network")
                    }
                    .disabled(isWorking)
                } header: {
                    Text("Simulate")
                } footer: {
                    Text("Each action logs with Logger (or print), like a real app would. Open the console with the button in the toolbar, or shake the device.")
                }

                Section {
                    Button("Report a Problem", systemImage: "exclamationmark.bubble") {
                        Task { try? await ISyslogShareSheet.shareCurrentSession() }
                    }
                } footer: {
                    Text("Shares the session straight from your own UI, without opening the console.")
                }
            }
            .navigationTitle("iSyslogKit Demo")
            .toolbar {
                Button("Logs", systemImage: "doc.text.magnifyingglass") { showsLogs = true }
            }
            .isyslogConsole(isPresented: $showsLogs)
            .isyslogConsoleOnShake()
            .task { Activity.sampleSession() }
        }
    }

    private func action(_ title: String, _ symbol: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Label(title, systemImage: symbol)
        }
    }
}
