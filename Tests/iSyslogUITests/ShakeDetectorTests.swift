#if canImport(UIKit) && !os(watchOS) && !os(tvOS)
import Testing
import UIKit
@testable import iSyslogUI

/// UIKit-only; runs with `xcodebuild test` on an iOS Simulator, not with `swift test` on macOS.
@MainActor
struct ShakeDetectorTests {
    /// Only touched on the main thread: the notification is posted synchronously from motionEnded.
    final class Counter: @unchecked Sendable { var shakes = 0 }

    @Test func windowShakePostsNotificationAndOtherRespondersAreUntouched() {
        ShakeDetector.install()
        ShakeDetector.install()  // idempotent

        let counter = Counter()
        let token = NotificationCenter.default.addObserver(forName: ShakeDetector.didShake, object: nil, queue: nil) { _ in
            counter.shakes += 1
        }
        defer { NotificationCenter.default.removeObserver(token) }

        let window = UIWindow(frame: .zero)
        window.motionEnded(.motionShake, with: nil)
        #expect(counter.shakes == 1)

        window.motionEnded(.remoteControlPlay, with: nil)
        #expect(counter.shakes == 1)

        // Plain views share UIResponder's implementation, which must not have been swapped.
        UIView().motionEnded(.motionShake, with: nil)
        #expect(counter.shakes == 1)
    }
}
#endif
