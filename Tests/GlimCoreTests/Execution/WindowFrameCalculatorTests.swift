import CoreGraphics
import Testing

@testable import GlimCore

struct WindowFrameCalculatorTests {
    // A 1440×900 primary screen with a 25 pt menu bar and a 60 pt Dock at the bottom.
    let primaryScreenHeight: CGFloat = 900
    let visibleFrame = CGRect(x: 0, y: 60, width: 1_440, height: 815)
    let currentSize = CGSize(width: 800, height: 600)

    func frame(for preset: WindowPreset) -> CGRect {
        WindowFrameCalculator.accessibilityFrame(
            for: preset, visibleFrame: visibleFrame, primaryScreenHeight: primaryScreenHeight,
            currentSize: currentSize)
    }

    @Test func leftHalfStartsBelowTheMenuBar() {
        #expect(frame(for: .leftHalf) == CGRect(x: 0, y: 25, width: 720, height: 815))
    }

    @Test func rightHalf() {
        #expect(frame(for: .rightHalf) == CGRect(x: 720, y: 25, width: 720, height: 815))
    }

    @Test func topHalfIsAtTheTopInAccessibilityCoordinates() {
        #expect(frame(for: .topHalf) == CGRect(x: 0, y: 25, width: 1_440, height: 407.5))
    }

    @Test func bottomHalfSitsAboveTheDock() {
        #expect(frame(for: .bottomHalf) == CGRect(x: 0, y: 432.5, width: 1_440, height: 407.5))
    }

    @Test func fillUsesTheWholeVisibleArea() {
        #expect(frame(for: .fill) == CGRect(x: 0, y: 25, width: 1_440, height: 815))
    }

    @Test func centerKeepsTheWindowSize() {
        #expect(frame(for: .center) == CGRect(x: 320, y: 132.5, width: 800, height: 600))
    }

    @Test func centerShrinksAWindowLargerThanTheScreen() {
        let hugeWindowFrame = WindowFrameCalculator.accessibilityFrame(
            for: .center, visibleFrame: visibleFrame, primaryScreenHeight: primaryScreenHeight,
            currentSize: CGSize(width: 3_000, height: 2_000))

        #expect(hugeWindowFrame == CGRect(x: 0, y: 25, width: 1_440, height: 815))
    }
}
