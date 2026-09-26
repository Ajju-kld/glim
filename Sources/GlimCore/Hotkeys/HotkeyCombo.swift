import Carbon.HIToolbox

/// A global keyboard shortcut.
public struct HotkeyCombo: Sendable, Equatable {
    /// Business rule (spec §9.9): the kill switch, owned by the watchdog.
    public static let killSwitch = HotkeyCombo(
        identifier: 1, keyCode: UInt32(kVK_ANSI_K),
        carbonModifiers: UInt32(controlKey | optionKey | cmdKey), displayName: "⌃⌥⌘K")
    /// Business rule (spec §5.5): hold to talk. Not ⌃⌥Space, which macOS uses for input sources.
    public static let pushToTalk = HotkeyCombo(
        identifier: 2, keyCode: UInt32(kVK_ANSI_V),
        carbonModifiers: UInt32(controlKey | optionKey), displayName: "⌃⌥V")
    /// Business rule: turns screen chat (the glowing screen edge) on and off, next to the talk
    /// key.
    public static let screenChat = HotkeyCombo(
        identifier: 3, keyCode: UInt32(kVK_ANSI_S),
        carbonModifiers: UInt32(controlKey | optionKey), displayName: "⌃⌥S")

    /// Distinguishes this shortcut's events from other registered shortcuts.
    public let identifier: UInt32
    /// The virtual key code.
    public let keyCode: UInt32
    /// Carbon modifier flags.
    public let carbonModifiers: UInt32
    /// The symbol form shown to the person.
    public let displayName: String
}
