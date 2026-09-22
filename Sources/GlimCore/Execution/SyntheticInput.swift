import CoreGraphics
import Foundation

/// Builds and posts Glim's keyboard and scroll events.
///
/// Events are posted to the target app's process (`postToPid`) rather than into the global
/// event stream, so a sudden focus change can't redirect them to another app — and they don't
/// register as hardware input, which lets the takeover monitor tell them apart from a person.
enum SyntheticInput {
    /// Marks every event Glim creates, for diagnostics.
    static let glimEventMarker: Int64 = 0x474C_494D
    /// Business rule: macOS accepts at most 20 UTF-16 units in one Unicode key event.
    static let maximumUnitsPerKeyEvent = 20
    /// Tunable: lets the app process each chunk before the next arrives.
    static let pauseBetweenChunks = Duration.milliseconds(15)
    /// Tunable: lines per scroll step.
    static let linesPerScroll: Int32 = 5

    private static let virtualKeyCodes: [AllowedKey: CGKeyCode] = [
        .tab: 48, .escape: 53, .returnKey: 36, .leftArrow: 123, .rightArrow: 124,
        .downArrow: 125, .upArrow: 126,
    ]
    private static let unusedVirtualKey: CGKeyCode = 0

    static func virtualKeyCode(for key: AllowedKey) -> CGKeyCode {
        virtualKeyCodes[key] ?? unusedVirtualKey
    }

    /// Splits `text` into UTF-16 chunks of at most `maximumUnitsPerChunk` units without splitting
    /// a character (a character longer than the limit gets a chunk of its own).
    static func utf16Chunks(of text: String, maximumUnitsPerChunk: Int) -> [[UInt16]] {
        var chunks: [[UInt16]] = []
        var currentChunk: [UInt16] = []
        for character in text {
            let characterUnits = Array(String(character).utf16)
            if !currentChunk.isEmpty,
                currentChunk.count + characterUnits.count > maximumUnitsPerChunk
            {
                chunks.append(currentChunk)
                currentChunk = []
            }
            currentChunk.append(contentsOf: characterUnits)
        }
        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }
        return chunks
    }

    static func postText(_ utf16Units: [UInt16], to processIdentifier: pid_t) throws(ExecutionError)
    {
        let source = CGEventSource(stateID: .privateState)
        guard
            let keyDown = CGEvent(
                keyboardEventSource: source, virtualKey: unusedVirtualKey, keyDown: true),
            let keyUp = CGEvent(
                keyboardEventSource: source, virtualKey: unusedVirtualKey, keyDown: false)
        else {
            throw .cannotCreateInputEvent
        }
        utf16Units.withUnsafeBufferPointer { units in
            keyDown.keyboardSetUnicodeString(
                stringLength: units.count, unicodeString: units.baseAddress)
            keyUp.keyboardSetUnicodeString(
                stringLength: units.count, unicodeString: units.baseAddress)
        }
        post([keyDown, keyUp], to: processIdentifier)
    }

    static func postKey(_ key: AllowedKey, to processIdentifier: pid_t) throws(ExecutionError) {
        let source = CGEventSource(stateID: .privateState)
        let keyCode = virtualKeyCode(for: key)
        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else {
            throw .cannotCreateInputEvent
        }
        post([keyDown, keyUp], to: processIdentifier)
    }

    static func postScroll(_ direction: ScrollDirection, to processIdentifier: pid_t)
        throws(ExecutionError)
    {
        let lines = direction == .up ? linesPerScroll : -linesPerScroll
        guard
            let scroll = CGEvent(
                scrollWheelEvent2Source: CGEventSource(stateID: .privateState), units: .line,
                wheelCount: 1, wheel1: lines, wheel2: 0, wheel3: 0)
        else {
            throw .cannotCreateInputEvent
        }
        post([scroll], to: processIdentifier)
    }

    private static func post(_ events: [CGEvent], to processIdentifier: pid_t) {
        for event in events {
            event.setIntegerValueField(.eventSourceUserData, value: glimEventMarker)
            event.postToPid(processIdentifier)
        }
    }
}
