import AppKit
import Testing

@testable import GlimCore

struct ClickOnlyRuleTests {
    @Test(arguments: [NSEvent.EventType.leftMouseUp, .leftMouseDown])
    func realMouseClicksCount(eventType: NSEvent.EventType) {
        #expect(ClickOnlyRule.isMouseClick(eventType))
    }

    @Test(arguments: [
        NSEvent.EventType.keyDown, .keyUp, .rightMouseUp, .otherMouseUp, .scrollWheel,
    ])
    func keyboardAndOtherEventsDoNot(eventType: NSEvent.EventType) {
        #expect(!ClickOnlyRule.isMouseClick(eventType))
    }

    @Test func noEventDoesNotCount() {
        #expect(!ClickOnlyRule.isMouseClick(nil))
    }

    @Test func buttonsArmAfterAShortDelay() {
        #expect(ClickOnlyRule.armingDelay == .milliseconds(800))
    }
}
