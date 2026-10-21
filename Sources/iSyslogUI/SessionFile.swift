import CoreTransferable
import UniformTypeIdentifiers
import iSyslogKit

extension UTType {
    /// The `.isyslog` session file. Apps that open sessions (the iSyslog app) declare it as
    /// `com.gammaproject.isyslog.session`; elsewhere this falls back to a type derived from the extension.
    public static let isyslogSession = UTType(filenameExtension: Session.fileExtension, conformingTo: .json) ?? .json
}

/// A session that is only written to disk when the user actually picks a share destination.
/// Used on macOS; on iOS the console shares a file URL instead (see `ISyslogShareSheet`).
struct SessionFile: Transferable {
    let make: @Sendable () async throws -> URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .isyslogSession) { file in
            SentTransferredFile(try await file.make())
        }
    }
}
