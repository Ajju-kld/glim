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
