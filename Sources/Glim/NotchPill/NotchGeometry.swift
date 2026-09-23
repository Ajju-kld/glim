import AppKit
import GlimCore

/// Where the pill's window sits: flush with the top of the screen and centered on the notch,
/// or just under the menu bar on screens without a notch.
struct NotchGeometry: Equatable {
    /// Tunable: gap below the menu bar on screens without a notch.
    static let floatingTopGap: CGFloat = 8
    /// Tunable: on screens without a notch, the pill shrinks to a sliver this wide.
    static let floatingTuckedWidth: CGFloat = 120
    /// Tunable: room around the pill inside the window for its glow.
    static let glowMargin: CGFloat = 24

    /// The window frame, big enough for the largest pill and its glow.
    let frame: CGRect
    /// The notch's size, which is the pill's size when tucked away; zero height without a notch.
    let notchSize: CGSize

    var hasNotch: Bool {
        notchSize.height > 0
    }

    init(screen: NSScreen) {
        let notchHeight = screen.safeAreaInsets.top
        if notchHeight > 0, let leftArea = screen.auxiliaryTopLeftArea,
            let rightArea = screen.auxiliaryTopRightArea
        {
            let notchWidth = screen.frame.width - leftArea.width - rightArea.width
            notchSize = CGSize(width: notchWidth, height: notchHeight)
        } else {
            notchSize = CGSize(width: Self.floatingTuckedWidth, height: 0)
        }
        let largestPill = PillLayout.largestSize(notchSize: notchSize)
        let width =
            largestPill.width + 2 * NotchPillShape.shoulderSize + 2 * Self.glowMargin
        let height = largestPill.height + Self.glowMargin
        let top =
            notchHeight > 0 ? screen.frame.maxY : screen.visibleFrame.maxY - Self.floatingTopGap
        frame = CGRect(
            x: screen.frame.midX - width / 2, y: top - height, width: width, height: height)
    }
}
