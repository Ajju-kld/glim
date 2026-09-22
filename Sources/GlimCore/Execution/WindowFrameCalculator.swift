import CoreGraphics

/// Computes window frames for the fixed presets.
///
/// Screens report frames in AppKit coordinates (origin at the bottom-left of the primary
/// screen); the Accessibility API positions windows in top-left coordinates. The result is in
/// Accessibility coordinates.
enum WindowFrameCalculator {
    static func accessibilityFrame(
        for preset: WindowPreset,
        visibleFrame: CGRect,
        primaryScreenHeight: CGFloat,
        currentSize: CGSize
    ) -> CGRect {
        let appKitFrame = appKitFrame(
            for: preset, visibleFrame: visibleFrame, currentSize: currentSize)
        return CGRect(
            x: appKitFrame.minX,
            y: primaryScreenHeight - appKitFrame.maxY,
            width: appKitFrame.width,
            height: appKitFrame.height)
    }

    private static func appKitFrame(
        for preset: WindowPreset, visibleFrame: CGRect, currentSize: CGSize
    ) -> CGRect {
        let halfWidth = visibleFrame.width / 2
        let halfHeight = visibleFrame.height / 2
        switch preset {
        case .leftHalf:
            return CGRect(
                x: visibleFrame.minX, y: visibleFrame.minY, width: halfWidth,
                height: visibleFrame.height)
        case .rightHalf:
            return CGRect(
                x: visibleFrame.midX, y: visibleFrame.minY, width: halfWidth,
                height: visibleFrame.height)
        case .topHalf:
            return CGRect(
                x: visibleFrame.minX, y: visibleFrame.midY, width: visibleFrame.width,
                height: halfHeight)
        case .bottomHalf:
            return CGRect(
                x: visibleFrame.minX, y: visibleFrame.minY, width: visibleFrame.width,
                height: halfHeight)
        case .fill:
            return visibleFrame
        case .center:
            let width = min(currentSize.width, visibleFrame.width)
            let height = min(currentSize.height, visibleFrame.height)
            return CGRect(
                x: visibleFrame.minX + (visibleFrame.width - width) / 2,
                y: visibleFrame.minY + (visibleFrame.height - height) / 2,
                width: width,
                height: height)
        }
    }
}
