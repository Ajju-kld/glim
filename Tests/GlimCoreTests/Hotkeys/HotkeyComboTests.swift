import Carbon.HIToolbox
import Testing

@testable import GlimCore

struct HotkeyComboTests {
    @Test func killSwitchIsControlOptionCommandK() {
        #expect(HotkeyCombo.killSwitch.keyCode == UInt32(kVK_ANSI_K))
        #expect(HotkeyCombo.killSwitch.carbonModifiers == UInt32(controlKey | optionKey | cmdKey))
        #expect(HotkeyCombo.killSwitch.displayName == "⌃⌥⌘K")
    }

    @Test func pushToTalkIsControlOptionV() {
        #expect(HotkeyCombo.pushToTalk.keyCode == UInt32(kVK_ANSI_V))
        #expect(HotkeyCombo.pushToTalk.carbonModifiers == UInt32(controlKey | optionKey))
        #expect(HotkeyCombo.pushToTalk.displayName == "⌃⌥V")
    }

    @Test func screenChatIsControlOptionS() {
        #expect(HotkeyCombo.screenChat.keyCode == UInt32(kVK_ANSI_S))
        #expect(HotkeyCombo.screenChat.carbonModifiers == UInt32(controlKey | optionKey))
        #expect(HotkeyCombo.screenChat.displayName == "⌃⌥S")
    }

    @Test func combosHaveDistinctIdentifiers() {
        let identifiers = [
            HotkeyCombo.killSwitch.identifier, HotkeyCombo.pushToTalk.identifier,
            HotkeyCombo.screenChat.identifier,
        ]
        #expect(Set(identifiers).count == identifiers.count)
    }
}
