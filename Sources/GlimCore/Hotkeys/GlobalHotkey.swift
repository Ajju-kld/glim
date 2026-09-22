import Carbon.HIToolbox

/// A system-wide shortcut through Carbon's `RegisterEventHotKey`, which needs no permission and
/// reports both press and release (for hold-to-talk).
@MainActor
public final class GlobalHotkey {
    /// Why a shortcut could not be registered.
    public enum RegistrationError: Error, Sendable, Equatable {
        /// Another app already owns the shortcut, or Carbon refused it.
        case registrationFailed(combo: String, status: Int32)
    }

    /// "GLIM" as a four-character code, marking Glim's shortcuts.
    private static let signature: OSType = 0x474C_494D

    private let combo: HotkeyCombo
    private let onPress: @MainActor () -> Void
    private let onRelease: (@MainActor () -> Void)?
    private var hotKeyReference: EventHotKeyRef?
    private var eventHandlerReference: EventHandlerRef?

    /// Creates an unregistered shortcut.
    public init(
        combo: HotkeyCombo, onPress: @escaping @MainActor () -> Void,
        onRelease: (@MainActor () -> Void)? = nil
    ) {
        self.combo = combo
        self.onPress = onPress
        self.onRelease = onRelease
    }

    /// Registers the shortcut with the system.
    public func register() throws(RegistrationError) {
        guard hotKeyReference == nil else {
            return
        }
        var eventTypes = [
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else {
                    return OSStatus(eventNotHandledErr)
                }
                var hotKeyIdentifier = EventHotKeyID()
                let parameterStatus = GetEventParameter(
                    event, EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyIdentifier)
                guard parameterStatus == noErr else {
                    return parameterStatus
                }
                let eventKind = GetEventKind(event)
                let hotkey = Unmanaged<GlobalHotkey>.fromOpaque(userData).takeUnretainedValue()
                // Carbon delivers hot-key events on the main thread.
                return MainActor.assumeIsolated {
                    hotkey.handle(eventKind: eventKind, hotKeyIdentifier: hotKeyIdentifier)
                }
            },
            eventTypes.count, &eventTypes, Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerReference)
        guard handlerStatus == noErr else {
            throw .registrationFailed(combo: combo.displayName, status: handlerStatus)
        }
        let hotKeyIdentifier = EventHotKeyID(signature: Self.signature, id: combo.identifier)
        let registrationStatus = RegisterEventHotKey(
            combo.keyCode, combo.carbonModifiers, hotKeyIdentifier, GetApplicationEventTarget(), 0,
            &hotKeyReference)
        guard registrationStatus == noErr else {
            unregister()
            throw .registrationFailed(combo: combo.displayName, status: registrationStatus)
        }
    }

    /// Unregisters the shortcut.
    public func unregister() {
        if let hotKeyReference {
            UnregisterEventHotKey(hotKeyReference)
            self.hotKeyReference = nil
        }
        if let eventHandlerReference {
            RemoveEventHandler(eventHandlerReference)
            self.eventHandlerReference = nil
        }
    }

    private func handle(eventKind: UInt32, hotKeyIdentifier: EventHotKeyID) -> OSStatus {
        guard hotKeyIdentifier.signature == Self.signature, hotKeyIdentifier.id == combo.identifier
        else {
            return OSStatus(eventNotHandledErr)
        }
        switch Int(eventKind) {
        case kEventHotKeyPressed:
            onPress()
        case kEventHotKeyReleased:
            onRelease?()
        default:
            return OSStatus(eventNotHandledErr)
        }
        return noErr
    }
}
