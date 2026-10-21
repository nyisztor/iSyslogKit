import Foundation

/// A captured set of log entries plus the context needed to make sense of them,
/// stored as a `.isyslog` file that testers share and the iSyslog app opens.
///
/// The file is JSON. Readers ignore keys they don't know, so later versions can add
/// fields (e.g. network entries) without breaking older apps. Changes older readers
/// can't handle must bump `currentFormatVersion`.
public struct Session: Codable, Sendable, Equatable {
    public static let currentFormatVersion = 1
    public static let fileExtension = "isyslog"
    public static let typeIdentifier = "com.gammaproject.isyslog.session"

    public struct Metadata: Codable, Sendable, Hashable {
        public var appName: String
        public var appVersion: String
        public var appBuild: String
        public var bundleID: String
        /// Hardware identifier, e.g. `iPhone16,1`.
        public var deviceModel: String
        public var systemName: String
        public var systemVersion: String
        public var createdAt: Date
        public var kitVersion: String

        public init(
            appName: String,
            appVersion: String,
            appBuild: String,
            bundleID: String,
            deviceModel: String,
            systemName: String,
            systemVersion: String,
            createdAt: Date,
            kitVersion: String
        ) {
            self.appName = appName
            self.appVersion = appVersion
            self.appBuild = appBuild
            self.bundleID = bundleID
            self.deviceModel = deviceModel
            self.systemName = systemName
            self.systemVersion = systemVersion
            self.createdAt = createdAt
            self.kitVersion = kitVersion
        }
    }

    public enum FileError: Error, Equatable {
        /// Written by a newer version of iSyslogKit than this reader understands.
        case unsupportedFormatVersion(Int)
    }

    public var formatVersion: Int
    public var metadata: Metadata
    public var entries: [LogEntry]

    public init(metadata: Metadata, entries: [LogEntry]) {
        self.formatVersion = Self.currentFormatVersion
        self.metadata = metadata
        self.entries = entries
    }

    /// The time span the entries cover, or `nil` for an empty session.
    public var dateRange: ClosedRange<Date>? {
        guard let first = entries.first?.date, let last = entries.last?.date else { return nil }
        return min(first, last)...max(first, last)
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        // Seconds since 1970 as a Double keeps sub-microsecond precision and is easy to read elsewhere.
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(self)
    }

    /// Writes the session to a uniquely named `.isyslog` file in the temporary directory, ready to share.
    public func writeToTemporaryFile() throws -> URL {
        let stamp = metadata.createdAt.formatted(
            .iso8601.year().month().day().dateSeparator(.dash).time(includingFractionalSeconds: false).timeSeparator(.omitted)
        )
        let name = "\(metadata.appName) \(stamp).\(Self.fileExtension)".replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try encoded().write(to: url, options: .atomic)
        return url
    }

    public init(decoding data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        // Check the version first so a newer file fails with a clear error, not a decoding error.
        struct Header: Decodable { var formatVersion: Int }
        let version = try decoder.decode(Header.self, from: data).formatVersion
        guard version <= Self.currentFormatVersion else {
            throw FileError.unsupportedFormatVersion(version)
        }
        self = try decoder.decode(Session.self, from: data)
    }
}
