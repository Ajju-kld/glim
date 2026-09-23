import CoreGraphics
import Testing

@testable import GlimCore

struct VisualTargetTests {
    let windowFrame = CGRect(x: 100, y: 200, width: 800, height: 600)

    func target(gridX: Int, gridY: Int) -> VisualTarget {
        VisualTarget(windowFrame: windowFrame, gridX: gridX, gridY: gridY, description: "Play")
    }

    @Test func gridPointMapsOntoTheWindowInScreenPoints() {
        #expect(target(gridX: 0, gridY: 0).screenPoint == CGPoint(x: 100, y: 200))
        #expect(target(gridX: 500, gridY: 500).screenPoint == CGPoint(x: 500, y: 500))
        #expect(target(gridX: 250, gridY: 750).screenPoint == CGPoint(x: 300, y: 650))
    }

    @Test func pointInTheWindowBodyIsClickable() {
        #expect(target(gridX: 500, gridY: 500).isInsideClickableArea)
        #expect(target(gridX: 999, gridY: 999).isInsideClickableArea)
    }

    /// The window's close, minimize and zoom buttons sit in the title bar, so it is never hit.
    @Test func pointInTheTitleBarStripIsNotClickable() {
        let titleBarGridY = Int(
            (VisualTarget.titleBarHeight - 1) / windowFrame.height * CGFloat(VisualTarget.gridSize))
        #expect(!target(gridX: 20, gridY: 0).isInsideClickableArea)
        #expect(!target(gridX: 20, gridY: titleBarGridY).isInsideClickableArea)
    }

    @Test(arguments: [(-1, 500), (500, -1), (1_000, 500), (500, 1_000), (5_000, 5_000)])
    func pointOutsideTheGridIsNotClickable(gridX: Int, gridY: Int) {
        #expect(!target(gridX: gridX, gridY: gridY).isInsideClickableArea)
    }

    @Test func windowThatStayedPutStillMatches() {
        #expect(target(gridX: 500, gridY: 500).windowStillMatches(windowFrame))
        let nudged = windowFrame.offsetBy(dx: VisualTarget.windowMoveTolerance, dy: 0)
        #expect(target(gridX: 500, gridY: 500).windowStillMatches(nudged))
    }

    @Test func movedOrResizedWindowNoLongerMatches() {
        let tolerance = VisualTarget.windowMoveTolerance
        let moved = windowFrame.offsetBy(dx: 0, dy: tolerance + 1)
        let resized = CGRect(
            origin: windowFrame.origin,
            size: CGSize(width: windowFrame.width + tolerance + 1, height: windowFrame.height))
        #expect(!target(gridX: 500, gridY: 500).windowStillMatches(moved))
        #expect(!target(gridX: 500, gridY: 500).windowStillMatches(resized))
    }
}
