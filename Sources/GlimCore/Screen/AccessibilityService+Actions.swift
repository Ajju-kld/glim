import ApplicationServices
import Foundation

/// Actions on live elements. Each re-checks the element against its snapshot first, so a
/// control that changed since it was read is never pressed or typed into.
extension AccessibilityService {
    func press(
        elementNumber: Int, expected: UIElementSnapshot, processIdentifier: pid_t,
        killSwitch: KillSwitch
    ) throws(ExecutionError) {
        let element = try verifiedElement(
            number: elementNumber, expected: expected, processIdentifier: processIdentifier)
        try Self.ensureArmed(killSwitch)
        let status = AXUIElementPerformAction(element, kAXPressAction as CFString)
        guard status == .success else {
            throw .actionFailed(
                reason: "Pressing “\(expected.label)” failed (code \(status.rawValue)).")
        }
    }

    func focusTextField(
        elementNumber: Int, expected: UIElementSnapshot, processIdentifier: pid_t,
        killSwitch: KillSwitch
    ) throws(ExecutionError) {
        let element = try verifiedElement(
            number: elementNumber, expected: expected, processIdentifier: processIdentifier)
        try Self.ensureArmed(killSwitch)
        let status = AXUIElementSetAttributeValue(
            element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        guard status == .success, isFocused(element, processIdentifier: processIdentifier) else {
            throw .focusNotOnTarget(label: expected.label)
        }
    }

    func focusedElementIs(elementNumber: Int, processIdentifier: pid_t) -> Bool {
        guard let element = liveElement(number: elementNumber, processIdentifier: processIdentifier)
        else {
            return false
        }
        return isFocused(element, processIdentifier: processIdentifier)
    }

    func focusedWindowFrame(processIdentifier: pid_t, appName: String) throws(ExecutionError)
        -> CGRect
    {
        let window = try window(of: processIdentifier, appName: appName)
        guard let position = Self.pointAttribute(kAXPositionAttribute, of: window),
            let size = Self.sizeAttribute(kAXSizeAttribute, of: window)
        else {
            throw .windowUnavailable(appName: appName)
        }
        return CGRect(origin: position, size: size)
    }

    func setFocusedWindowFrame(
        _ frame: CGRect, processIdentifier: pid_t, appName: String, killSwitch: KillSwitch
    ) throws(ExecutionError) {
        let window = try window(of: processIdentifier, appName: appName)
        var origin = frame.origin
        var size = frame.size
        guard let positionValue = AXValueCreate(.cgPoint, &origin),
            let sizeValue = AXValueCreate(.cgSize, &size)
        else {
            throw .actionFailed(reason: "Could not describe the window frame.")
        }
        try Self.ensureArmed(killSwitch)
        let positionStatus = AXUIElementSetAttributeValue(
            window, kAXPositionAttribute as CFString, positionValue)
        let sizeStatus = AXUIElementSetAttributeValue(
            window, kAXSizeAttribute as CFString, sizeValue)
        guard positionStatus == .success, sizeStatus == .success else {
            throw .actionFailed(reason: "\(appName) did not accept the new window frame.")
        }
    }

    func minimizeFocusedWindow(
        processIdentifier: pid_t, appName: String, killSwitch: KillSwitch
    ) throws(ExecutionError) {
        let window = try window(of: processIdentifier, appName: appName)
        try Self.ensureArmed(killSwitch)
        let status = AXUIElementSetAttributeValue(
            window, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
        guard status == .success else {
            throw .actionFailed(reason: "\(appName) did not minimize.")
        }
    }

    func restoreMinimizedWindow(
        processIdentifier: pid_t, appName: String, killSwitch: KillSwitch
    ) throws(ExecutionError) {
        let appElement = applicationElement(for: processIdentifier)
        var windowsValue: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
            let windows = windowsValue as? [AXUIElement],
            let minimizedWindow = windows.first(where: {
                Self.boolAttribute(kAXMinimizedAttribute, of: $0) == true
            })
        else {
            throw .windowUnavailable(appName: appName)
        }
        try Self.ensureArmed(killSwitch)
        let status = AXUIElementSetAttributeValue(
            minimizedWindow, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        guard status == .success else {
            throw .actionFailed(reason: "\(appName) did not restore its window.")
        }
    }

    // MARK: - Helpers

    /// The last check before an Accessibility call that changes something.
    private static func ensureArmed(_ killSwitch: KillSwitch) throws(ExecutionError) {
        guard killSwitch.isArmed else {
            throw .stopped
        }
    }

    private func verifiedElement(
        number: Int, expected: UIElementSnapshot, processIdentifier: pid_t
    ) throws(ExecutionError) -> AXUIElement {
        guard let element = liveElement(number: number, processIdentifier: processIdentifier) else {
            throw .elementChanged(label: expected.label)
        }
        let currentRole = Self.stringAttribute(kAXRoleAttribute, of: element)
        let currentSubrole = Self.stringAttribute(kAXSubroleAttribute, of: element)
        let isUnchanged =
            currentRole == expected.role
            && currentSubrole == expected.subrole
            && Self.stringAttribute(kAXTitleAttribute, of: element) == expected.title
            && Self.stringAttribute(kAXDescriptionAttribute, of: element)
                == expected.elementDescription
        let isSecure =
            currentRole == UIElementSnapshot.secureTextRole
            || currentSubrole == UIElementSnapshot.secureTextRole
        guard isUnchanged, !isSecure else {
            throw .elementChanged(label: expected.label)
        }
        return element
    }

    private func isFocused(_ element: AXUIElement, processIdentifier: pid_t) -> Bool {
        let appElement = applicationElement(for: processIdentifier)
        var focusedValue: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                appElement, kAXFocusedUIElementAttribute as CFString, &focusedValue)
                == .success,
            let focusedValue
        else {
            return false
        }
        return CFEqual(focusedValue, element)
    }

    private func window(of processIdentifier: pid_t, appName: String) throws(ExecutionError)
        -> AXUIElement
    {
        do {
            return try focusedWindow(
                of: applicationElement(for: processIdentifier), appName: appName)
        } catch {
            throw .accessibility(error)
        }
    }

    private static func pointAttribute(_ attributeName: String, of element: AXUIElement) -> CGPoint?
    {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attributeName as CFString, &value) == .success,
            let value, CFGetTypeID(value) == AXValueGetTypeID()
        else {
            return nil
        }
        var point = CGPoint.zero
        return AXValueGetValue(unsafeDowncast(value, to: AXValue.self), .cgPoint, &point)
            ? point : nil
    }

    private static func sizeAttribute(_ attributeName: String, of element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attributeName as CFString, &value) == .success,
            let value, CFGetTypeID(value) == AXValueGetTypeID()
        else {
            return nil
        }
        var size = CGSize.zero
        return AXValueGetValue(unsafeDowncast(value, to: AXValue.self), .cgSize, &size) ? size : nil
    }

    private static func boolAttribute(_ attributeName: String, of element: AXUIElement) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attributeName as CFString, &value) == .success
        else {
            return nil
        }
        return value as? Bool
    }
}
