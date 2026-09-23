import AppKit

/// Where the pill sits: merged with the notch like the Dynamic Island, or floating at
/// top-center on screens without a notch.
struct NotchGeometry {
    /// Tunable: height of the pill's content area below the notch.
    static let contentHeight: CGFloat = 52
    /// Tunable: pill width.
    static let pillWidth: CGFloat = 420
    /// Tunable: gap below the menu bar on screens without a notch.
    static let floatingTopGap: CGFloat = 8

    let frame: CGRect
    let notchHeight: CGFloat

    var hasNotch: Bool {
        notchHeight > 0
    }

    init(screen: NSScreen) {
        notchHeight = screen.safeAreaInsets.top
        let height = notchHeight + Self.contentHeight
        let originX = screen.frame.midX - Self.pillWidth / 2
        let originY =
            notchHeight > 0
            ? screen.frame.maxY - height
            : screen.visibleFrame.maxY - height - Self.floatingTopGap
        frame = CGRect(x: originX, y: originY, width: Self.pillWidth, height: height)
    }
}
