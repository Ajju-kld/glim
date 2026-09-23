import CoreGraphics
import Foundation

/// A point the model chose on a window screenshot, for a click step whose control Glim could
/// not read (see docs/specs/2026-09-23-see-and-click-design.md).
public struct VisualTarget: Sendable, Equatable {
    /// Business rule: qwen3-vl answers positions on a 0–1000 grid across the image.
    public static let gridSize = 1_000
    /// Tunable: the strip at the top of a window that is never clicked by sight. The close,
    /// minimize and zoom buttons live there, and Glim never uses them.
    public static let titleBarHeight: CGFloat = 28
    /// Tunable: how far the window may move or resize between capture and click, in points.
    public static let windowMoveTolerance: CGFloat = 2

    /// The window's frame in global screen points (top-left origin) when it was captured.
    public let windowFrame: CGRect
    /// Horizontal position on the grid, 0 at the image's left edge.
    public let gridX: Int
    /// Vertical position on the grid, 0 at the image's top edge.
    public let gridY: Int
    /// What the model says is at that point, shown to the person and checked for risk words.
    public let description: String

    /// Creates a target from the model's grid position on a capture of `windowFrame`.
    public init(windowFrame: CGRect, gridX: Int, gridY: Int, description: String) {
        self.windowFrame = windowFrame
        self.gridX = gridX
        self.gridY = gridY
        self.description = description
    }

    /// The point to click, in global screen points (top-left origin).
    public var screenPoint: CGPoint {
        let gridSize = CGFloat(Self.gridSize)
        return CGPoint(
            x: windowFrame.minX + windowFrame.width * CGFloat(gridX) / gridSize,
            y: windowFrame.minY + windowFrame.height * CGFloat(gridY) / gridSize)
    }

    /// Whether the point is inside the window and below its title-bar strip.
    public var isInsideClickableArea: Bool {
        let gridRange = 0..<Self.gridSize
        guard gridRange.contains(gridX), gridRange.contains(gridY) else {
            return false
        }
        return screenPoint.y >= windowFrame.minY + Self.titleBarHeight
    }

    /// Whether `liveFrame`, read right before clicking, is still the captured window's frame.
    public func windowStillMatches(_ liveFrame: CGRect) -> Bool {
        let tolerance = Self.windowMoveTolerance
        return abs(liveFrame.minX - windowFrame.minX) <= tolerance
            && abs(liveFrame.minY - windowFrame.minY) <= tolerance
            && abs(liveFrame.width - windowFrame.width) <= tolerance
            && abs(liveFrame.height - windowFrame.height) <= tolerance
    }
}

/// A click Glim found by sight: the screenshot the model looked at and the point it chose.
public struct VisualClick: Sendable, Equatable {
    /// The window screenshot, kept in memory only, shown in the confirmation panel.
    public let screenshotPNG: Data
    /// The chosen point.
    public let target: VisualTarget

    /// Creates a click found by sight.
    public init(screenshotPNG: Data, target: VisualTarget) {
        self.screenshotPNG = screenshotPNG
        self.target = target
    }
}
