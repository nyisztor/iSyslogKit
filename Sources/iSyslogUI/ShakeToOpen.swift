import SwiftUI

extension View {
    /// Opens the log console when the device is shaken (Device ▸ Shake in the Simulator).
    /// Opt-in: the shake hook is only installed once a view uses this modifier.
    public func isyslogConsoleOnShake() -> some View {
        modifier(ShakeToOpenConsole())
    }
}

private struct ShakeToOpenConsole: ViewModifier {
    @State private var isPresented = false

    func body(content: Content) -> some View {
        #if canImport(UIKit) && !os(watchOS) && !os(tvOS)
        content
            .onAppear { ShakeDetector.install() }
            .onReceive(NotificationCenter.default.publisher(for: ShakeDetector.didShake)) { _ in
                isPresented = true
            }
            .isyslogConsole(isPresented: $isPresented)
        #else
        content
        #endif
    }
}

#if canImport(UIKit) && !os(watchOS) && !os(tvOS)
import UIKit
import ObjectiveC

/// Reports shakes by hooking `UIWindow.motionEnded(_:with:)`.
///
/// Shake events travel up the responder chain and end at the window, but SwiftUI exposes no
/// hook for them. The hook is installed on `UIWindow` only (never on `UIResponder`, which
/// every view inherits from) and then calls the original implementation.
///
/// The original is called with its real selector. UIKit's implementation forwards the event
/// to the next responder using the selector it was called with, so the usual "swap two method
/// names" swizzle would forward an unknown selector to the window scene and crash.
@MainActor
enum ShakeDetector {
    nonisolated static let didShake = Notification.Name("iSyslogKit.deviceDidShake")

    private static var isInstalled = false

    static func install() {
        guard !isInstalled else { return }
        isInstalled = true

        let selector = #selector(UIResponder.motionEnded(_:with:))
        guard let originalMethod = class_getInstanceMethod(UIWindow.self, selector) else { return }
        let originalIMP = method_getImplementation(originalMethod)

        typealias MotionEnded = @convention(c) (AnyObject, Selector, UIEvent.EventSubtype, UIEvent?) -> Void
        let callOriginal = unsafeBitCast(originalIMP, to: MotionEnded.self)
        let hook: @convention(block) (AnyObject, UIEvent.EventSubtype, UIEvent?) -> Void = { window, motion, event in
            if motion == .motionShake {
                NotificationCenter.default.post(name: didShake, object: window)
            }
            callOriginal(window, selector, motion, event)
        }
        let hookIMP = imp_implementationWithBlock(hook)

        // If UIWindow only inherits motionEnded, this gives it its own (hooked) copy and leaves
        // UIResponder alone. If it has its own, replace that one.
        if !class_addMethod(UIWindow.self, selector, hookIMP, method_getTypeEncoding(originalMethod)) {
            method_setImplementation(originalMethod, hookIMP)
        }
    }
}
#endif
