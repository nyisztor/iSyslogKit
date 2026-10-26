import Foundation
@_exported import iSyslogCore
import StoreKit

/// Entry point for apps using iSyslogKit.
///
/// ```swift
/// @main struct MyApp: App {
///     init() { ISyslog.start() }
///     …
/// }
/// ```
@MainActor
public enum ISyslog {
    public nonisolated static let version = "0.2.0"

    public struct Configuration: Sendable {
        /// Which builds capture logs. Release builds from the App Store should normally not.
        public enum Activation: Sendable {
            case always
            case never
            /// Builds compiled with the `DEBUG` flag.
            case debugBuilds
            /// `DEBUG` builds and TestFlight installs.
            case debugAndTestFlightBuilds
        }

        public var activation: Activation
        /// Entries kept in memory; the oldest are dropped first.
        public var bufferCapacity: Int
        /// How often a visible console refreshes. Each refresh costs about 1.5 s of background work.
        public var pollInterval: Duration
        /// Captures `print` output. It still appears in Xcode's console as before.
        public var capturesStandardOutput: Bool
        /// Captures stderr. Off by default: when an app runs from Xcode, its `Logger` messages are
        /// also written to stderr and would show up twice.
        public var capturesStandardError: Bool

        public init(
            activation: Activation = .debugAndTestFlightBuilds,
            bufferCapacity: Int = 10_000,
            pollInterval: Duration = .seconds(3),
            capturesStandardOutput: Bool = true,
            capturesStandardError: Bool = false
        ) {
            self.activation = activation
            self.bufferCapacity = bufferCapacity
            self.pollInterval = pollInterval
            self.capturesStandardOutput = capturesStandardOutput
            self.capturesStandardError = capturesStandardError
        }
    }

    /// The running capture, or `nil` if iSyslogKit isn't active in this build.
    /// With `.debugAndTestFlightBuilds` in a non-DEBUG build, it appears shortly after
    /// `start()` once the TestFlight check has finished.
    public private(set) static var capture: LogCapture?

    /// Starts iSyslogKit if `configuration.activation` allows it in this build. Safe to call more than once.
    public static func start(_ configuration: Configuration = .init()) {
        guard capture == nil else { return }
        switch configuration.activation {
        case .always:
            activate(configuration)
        case .never:
            break
        case .debugBuilds:
            if isDebugBuild { activate(configuration) }
        case .debugAndTestFlightBuilds:
            if isDebugBuild {
                activate(configuration)
            } else {
                Task {
                    if await isTestFlightInstall() { activate(configuration) }
                }
            }
        }
    }

    private static func activate(_ configuration: Configuration) {
        guard capture == nil else { return }
        let newCapture = LogCapture(configuration: configuration)
        capture = newCapture
        newCapture.startCapturingStandardStreams()
    }

    // DEBUG here is how the package was compiled, which in Xcode follows the app's build configuration.
    private static var isDebugBuild: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    /// TestFlight installs are signed for the sandbox App Store environment.
    private static func isTestFlightInstall() async -> Bool {
        guard let result = try? await AppTransaction.shared else { return false }
        switch result {
        case .verified(let transaction), .unverified(let transaction, _):
            return transaction.environment == .sandbox
        }
    }
}
