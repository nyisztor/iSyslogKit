import Foundation
import iSyslogCore

extension Session.Metadata {
    /// Describes the running app and device.
    static func current(bundle: Bundle = .main, now: Date = Date()) -> Session.Metadata {
        let info = bundle.infoDictionary ?? [:]
        let processInfo = ProcessInfo.processInfo
        let model = hardwareModel()
        let version = processInfo.operatingSystemVersion
        return Session.Metadata(
            appName: info["CFBundleDisplayName"] as? String
                ?? info["CFBundleName"] as? String
                ?? processInfo.processName,
            appVersion: info["CFBundleShortVersionString"] as? String ?? "",
            appBuild: info["CFBundleVersion"] as? String ?? "",
            bundleID: bundle.bundleIdentifier ?? "",
            deviceModel: model,
            systemName: systemName(model: model),
            systemVersion: "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)",
            createdAt: now,
            kitVersion: ISyslog.version
        )
    }

    /// `hw.machine` on iOS (e.g. `iPhone16,1`), `hw.model` on macOS (e.g. `Mac17,2`).
    /// In the Simulator `hw.machine` is just the host CPU (`arm64`), so use the simulated model.
    private static func hardwareModel() -> String {
        #if targetEnvironment(simulator)
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }
        #endif
        #if os(macOS)
        let key = "hw.model"
        #else
        let key = "hw.machine"
        #endif
        var size = 0
        guard sysctlbyname(key, nil, &size, nil, 0) == 0, size > 0 else { return "" }
        var bytes = [CChar](repeating: 0, count: size)
        guard sysctlbyname(key, &bytes, &size, nil, 0) == 0 else { return "" }
        return String(decoding: bytes.prefix { $0 != 0 }.map(UInt8.init), as: UTF8.self)
    }

    private static func systemName(model: String) -> String {
        #if os(macOS)
        return "macOS"
        #elseif os(visionOS)
        return "visionOS"
        #elseif os(iOS)
        if ProcessInfo.processInfo.isiOSAppOnMac { return "macOS" }
        return model.hasPrefix("iPad") ? "iPadOS" : "iOS"
        #else
        return ""
        #endif
    }
}
