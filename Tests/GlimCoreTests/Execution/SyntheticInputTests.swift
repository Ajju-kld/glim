import Foundation
import Testing

@testable import GlimCore

struct SyntheticInputTests {
    @Test func textIsSplitWithoutBreakingCharacters() {
        let text = String(repeating: "a", count: 19) + "👨‍👩‍👧" + "bc"

        let chunks = SyntheticInput.utf16Chunks(of: text, maximumUnitsPerChunk: 20)

        #expect(chunks.allSatisfy { $0.count <= 20 || $0 == Array("👨‍👩‍👧".utf16) })
        #expect(String(decoding: chunks.flatMap { $0 }, as: UTF16.self) == text)
        #expect(chunks.map { String(decoding: $0, as: UTF16.self) }.contains("👨‍👩‍👧bc"))
    }

    @Test func emptyTextHasNoChunks() {
        #expect(SyntheticInput.utf16Chunks(of: "", maximumUnitsPerChunk: 20).isEmpty)
    }

    @Test(arguments: [
        (AllowedKey.tab, 48), (.escape, 53), (.returnKey, 36), (.leftArrow, 123),
        (.rightArrow, 124), (.downArrow, 125), (.upArrow, 126),
    ])
    func allowedKeysMapToMacKeyCodes(key: AllowedKey, keyCode: Int) {
        #expect(Int(SyntheticInput.virtualKeyCode(for: key)) == keyCode)
    }
}

struct SyntheticInputKillSwitchTests {
    @Test func trippedKillSwitchBlocksKeyEventsAtTheLastMoment() {
        let killSwitch = KillSwitch()
        killSwitch.trip(.killHotkey)

        #expect(throws: ExecutionError.stopped) {
            try SyntheticInput.postKey(.tab, to: getpid(), killSwitch: killSwitch)
        }
    }

    @Test func trippedKillSwitchBlocksTypedTextAtTheLastMoment() {
        let killSwitch = KillSwitch()
        killSwitch.trip(.stopButton)

        #expect(throws: ExecutionError.stopped) {
            try SyntheticInput.postText(Array("hi".utf16), to: getpid(), killSwitch: killSwitch)
        }
    }

    @Test func trippedKillSwitchBlocksScrollingAtTheLastMoment() {
        let killSwitch = KillSwitch()
        killSwitch.trip(.humanTookOver)

        #expect(throws: ExecutionError.stopped) {
            try SyntheticInput.postScroll(.down, at: nil, to: getpid(), killSwitch: killSwitch)
        }
    }
}
