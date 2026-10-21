import SwiftUI

#if canImport(UIKit) && !os(watchOS) && !os(tvOS)
import UIKit

/// Shares a session file through the system share sheet.
///
/// The file is passed as a URL on purpose: only then does iOS offer apps that open the
/// document type ("iSyslog" in the app row). SwiftUI's `ShareLink` with a lazily written
/// `Transferable` file doesn't get that row.
@MainActor
public enum ISyslogShareSheet {
    /// Presents the share sheet for a file, anchored near the top trailing corner of the
    /// front-most screen (where the console's Share button is).
    public static func present(fileAt url: URL) {
        guard let top = frontmostViewController() else { return }
        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = top.view
            popover.sourceRect = CGRect(x: top.view.bounds.maxX - 56, y: top.view.safeAreaInsets.top + 24, width: 1, height: 1)
            popover.permittedArrowDirections = [.up]
        }
        top.present(sheet, animated: true)
    }

    /// Captures everything so far into a session file and shares it, e.g. from a "Report a Problem" button.
    public static func shareCurrentSession() async throws {
        guard let capture = ISyslog.capture else { return }
        present(fileAt: try await capture.exportSession())
    }

    private static func frontmostViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        guard var top = (scene?.keyWindow ?? scene?.windows.first)?.rootViewController else { return nil }
        while let presented = top.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}
#endif

/// The console's Share button: writes the session file, then opens the share sheet.
struct ShareSessionButton: View {
    let title: String
    let makeFile: @Sendable () async throws -> URL

    #if canImport(UIKit) && !os(watchOS) && !os(tvOS)
    @State private var isPreparing = false

    var body: some View {
        Button {
            Task {
                isPreparing = true
                defer { isPreparing = false }
                if let url = try? await makeFile() {
                    ISyslogShareSheet.present(fileAt: url)
                }
            }
        } label: {
            if isPreparing {
                ProgressView()
            } else {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
        .disabled(isPreparing)
    }
    #else
    var body: some View {
        ShareLink(
            item: SessionFile(make: makeFile),
            preview: SharePreview(title, image: Image(systemName: "doc.text.magnifyingglass"))
        )
    }
    #endif
}
