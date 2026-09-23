import ApplicationServices

/// The switchboard backed by the Accessibility API, acting on each app's application element.
struct LiveAccessibilitySwitchboard: AccessibilitySwitchboard {
    func boolValue(of attribute: String, processIdentifier: pid_t) -> Bool? {
        var value: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                applicationElement(processIdentifier), attribute as CFString, &value) == .success
        else {
            return nil
        }
        return value as? Bool
    }

    func setBool(_ value: Bool, attribute: String, processIdentifier: pid_t) {
        // Older Electron reports `attributeUnsupported` even though the switch took effect, so
        // the status says nothing reliable; the next window read shows whether it worked.
        _ = AXUIElementSetAttributeValue(
            applicationElement(processIdentifier), attribute as CFString,
            value ? kCFBooleanTrue : kCFBooleanFalse)
    }

    func readRole(processIdentifier: pid_t) {
        var role: CFTypeRef?
        // Reading the role is what wakes the browser; the role itself isn't needed.
        _ = AXUIElementCopyAttributeValue(
            applicationElement(processIdentifier), kAXRoleAttribute as CFString, &role)
    }

    private func applicationElement(_ processIdentifier: pid_t) -> AXUIElement {
        let element = AXUIElementCreateApplication(processIdentifier)
        AXUIElementSetMessagingTimeout(element, ScreenReadingLimits.messagingTimeoutSeconds)
        return element
    }
}
