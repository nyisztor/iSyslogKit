// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "iSyslogKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        // What app developers add: capture and export (iSyslogKit) plus the console (iSyslogUI).
        .library(name: "iSyslogKit", targets: ["iSyslogKit", "iSyslogUI"]),
        // The model and session file format on their own, without the UI.
        .library(name: "iSyslogCore", targets: ["iSyslogCore"]),
    ],
    targets: [
        .target(name: "iSyslogCore"),
        .target(name: "iSyslogKit", dependencies: ["iSyslogCore"]),
        .target(name: "iSyslogUI", dependencies: ["iSyslogKit"]),
        .testTarget(name: "iSyslogCoreTests", dependencies: ["iSyslogCore"]),
        .testTarget(name: "iSyslogKitTests", dependencies: ["iSyslogKit"]),
        .testTarget(name: "iSyslogUITests", dependencies: ["iSyslogUI"]),
    ]
)
