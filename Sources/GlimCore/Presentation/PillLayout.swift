import CoreGraphics

/// The notch pill's size in each state. Hidden, it is exactly the notch, so it grows out of
/// the notch and shrinks back into it.
public enum PillLayout {
    /// Tunable: height of the pill's content below the notch.
    public static let contentHeight: CGFloat = 60
    /// Tunable: width when the pill shows a line of status.
    public static let expandedWidth: CGFloat = 420
    /// Tunable: width while listening before any words arrive, and for "Done".
    public static let compactWidth: CGFloat = 260
    /// Tunable: the pill is always at least this much wider than the notch on each side.
    public static let minimumSideOverhang: CGFloat = 36

    /// The pill's size for `status` on a screen whose notch is `notchSize` (zero without one).
    public static func size(for status: PillStatus, notchSize: CGSize) -> CGSize {
        let width: CGFloat
        switch status {
        case .hidden:
            return notchSize
        case .listening(let transcript, _):
            width = transcript.isEmpty ? compactWidth : expandedWidth
        case .done:
            width = compactWidth
        case .thinking, .waitingForYou, .acting, .stopped:
            width = expandedWidth
        }
        return CGSize(
            width: max(width, notchSize.width + 2 * minimumSideOverhang),
            height: notchSize.height + contentHeight)
    }

    /// A size every state fits in, for the window that hosts the pill.
    public static func largestSize(notchSize: CGSize) -> CGSize {
        CGSize(
            width: max(expandedWidth, notchSize.width + 2 * minimumSideOverhang),
            height: notchSize.height + contentHeight)
    }
}
