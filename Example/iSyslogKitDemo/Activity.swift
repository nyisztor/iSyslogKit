import Foundation
import OSLog

/// Logs what a typical app would log while doing its work.
enum Activity {
    static let subsystem = "com.example.isyslogkit.demo"
    static let auth = Logger(subsystem: subsystem, category: "Auth")
    static let sync = Logger(subsystem: subsystem, category: "Sync")
    static let network = Logger(subsystem: subsystem, category: "Network")
    static let storage = Logger(subsystem: subsystem, category: "Storage")
    static let ui = Logger(subsystem: subsystem, category: "UI")

    static func signIn() {
        let email = "taylor@example.com"
        ui.debug("Sign-in button tapped")
        auth.info("Starting sign-in for \(email)")
        auth.debug("Token cache miss, requesting new token")
        auth.notice("Signed in as \(email) (account tier: \("pro", privacy: .public))")
    }

    static func syncPhotos() {
        let count = Int.random(in: 18...64)
        sync.info("Sync started: \(count, privacy: .public) photos queued")
        for batch in 1...3 {
            sync.debug("Uploading batch \(batch, privacy: .public)/3")
        }
        if Bool.random() {
            sync.error("Batch 2 retried after timeout (attempt \(2, privacy: .public))")
        }
        sync.notice("Sync finished: \(count, privacy: .public) photos in \(Double.random(in: 1.2...4.8), format: .fixed(precision: 1), privacy: .public) s")
    }

    static func networkFailure() {
        network.info("GET /v2/feed")
        network.error("Request failed: HTTP \(503, privacy: .public) Service Unavailable, retry in \(30, privacy: .public) s")
        ui.notice("Showing offline banner")
    }

    static func databaseFault() {
        storage.error("Migration step 7 failed: column 'createdAt' missing")
        storage.fault("Persistent store could not be opened; falling back to in-memory store")
    }

    static func burst(count: Int) {
        for i in 1...count {
            ui.debug("Scroll offset changed: \(i * 12, privacy: .public) pt")
        }
        ui.info("Logged \(count, privacy: .public) scroll events")
    }

    static func printSomething() {
        print("print(): cart has \(Int.random(in: 1...9)) items")
        print("print(): multi-line output\n  second line\n  third line")
    }

    static func realRequest() async {
        network.info("GET https://www.apple.com/library/test/success.html")
        do {
            let (_, response) = try await URLSession.shared.data(from: URL(string: "https://www.apple.com/library/test/success.html")!)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            network.notice("Response \(status, privacy: .public)")
        } catch {
            network.error("Request failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// A believable mix of everything, for screenshots and scripted test runs.
    static func sampleSession() {
        ui.notice("App launched (cold start)")
        printSomething()
        signIn()
        syncPhotos()
        networkFailure()
        burst(count: 40)
        syncPhotos()
        databaseFault()
        ui.info("Settings screen opened")
    }
}
