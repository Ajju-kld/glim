import AppKit

/// The screens' frames, read on the main actor where AppKit requires it.
struct ScreenGeometry: Sendable {
    struct Screen: Sendable {
        let frame: CGRect
        let visibleFrame: CGRect
    }

    let screens: [Screen]

    /// Height of the primary screen, which anchors both coordinate systems.
    var primaryScreenHeight: CGFloat {
        screens.first?.frame.height ?? 0
    }

    @MainActor
    static func current() -> ScreenGeometry {
        ScreenGeometry(
            screens: NSScreen.screens.map { Screen(frame: $0.frame, visibleFrame: $0.visibleFrame) }
        )
    }

    /// The visible frame of the screen containing the centre of a window given in Accessibility
    /// coordinates, falling back to the primary screen.
    func visibleFrame(containingAccessibilityFrame windowFrame: CGRect) -> CGRect? {
        let appKitCenter = CGPoint(x: windowFrame.midX, y: primaryScreenHeight - windowFrame.midY)
        let containingScreen = screens.first { $0.frame.contains(appKitCenter) } ?? screens.first
        return containingScreen?.visibleFrame
    }
}
