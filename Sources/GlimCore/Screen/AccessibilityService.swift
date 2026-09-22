import ApplicationServices
import Foundation

/// The live bridge to the macOS Accessibility API, for reading windows and acting on them.
///
/// Every `AXUIElement` stays inside this actor: tables are handed out as plain values, and an
/// action names an element by number. All calls run off the main thread with a short
/// messaging timeout, so a frozen app can't block Glim or the kill switch.
public actor AccessibilityService: ScreenReading {
    private struct TreeWalk {
        let deadline: ContinuousClock.Instant
        var nodesVisited = 0

        var canContinue: Bool {
            nodesVisited < ScreenReadingLimits.maximumNodes && ContinuousClock.now < deadline
        }
    }

    private struct NodeAttributes {
        var role = ""
        var subrole: String?
        var title: String?
        var elementDescription: String?
        var placeholder: String?
        var helpText: String?
        var identifier: String?
        var value: String?
        var isEnabled = true
        var size = CGSize.zero
        var children: [AXUIElement] = []
    }

    private static let attributeNames: [String] = [
        kAXRoleAttribute, kAXSubroleAttribute, kAXTitleAttribute, kAXDescriptionAttribute,
        kAXPlaceholderValueAttribute, kAXHelpAttribute, kAXIdentifierAttribute, kAXValueAttribute,
        kAXEnabledAttribute, kAXSizeAttribute, kAXChildrenAttribute,
    ]
    /// Electron apps expose their accessibility tree only after this attribute is set.
    private static let electronAccessibilityAttribute = "AXManualAccessibility"
    private static let trustPromptOption = "AXTrustedCheckOptionPrompt"

    private var handles: [AXUIElement] = []
    private var currentTable: ElementTable?
    private var currentProcessIdentifier: pid_t?
    private var electronAccessibilityEnabled: Set<pid_t> = []

    /// Creates the service.
    public init() {}

    /// Whether macOS lets Glim use the Accessibility API.
    public nonisolated static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system prompt that takes the person to the Accessibility settings.
    public nonisolated static func promptForTrust() {
        let options = [trustPromptOption: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Walks the app's focused window into a numbered table, within the reading limits.
    public func snapshotFrontWindow(
        of app: ResolvedApp
    ) throws(ScreenReadingError) -> ScreenSnapshot {
        guard Self.isTrusted else {
            throw .accessibilityNotTrusted
        }
        guard let processIdentifier = app.processIdentifier else {
            throw .appNotRunning(appName: app.identity.displayName)
        }
        let appElement = applicationElement(for: processIdentifier)
        let window = try focusedWindow(of: appElement, appName: app.identity.displayName)

        handles = []
        var walk = TreeWalk(deadline: ContinuousClock.now + ScreenReadingLimits.walkTimeBudget)
        let rootNode = node(for: window, depth: 0, walk: &walk)
        let table = ElementTableBuilder().build(from: rootNode)
        currentTable = table
        currentProcessIdentifier = processIdentifier
        return ScreenSnapshot(
            app: app, windowTitle: Self.stringAttribute(kAXTitleAttribute, of: window), table: table
        )
    }

    // MARK: - Shared with actions

    func applicationElement(for processIdentifier: pid_t) -> AXUIElement {
        let appElement = AXUIElementCreateApplication(processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, ScreenReadingLimits.messagingTimeoutSeconds)
        if !electronAccessibilityEnabled.contains(processIdentifier) {
            // Non-Electron apps ignore this attribute; the result is irrelevant either way.
            _ = AXUIElementSetAttributeValue(
                appElement, Self.electronAccessibilityAttribute as CFString, kCFBooleanTrue)
            electronAccessibilityEnabled.insert(processIdentifier)
        }
        return appElement
    }

    func focusedWindow(of appElement: AXUIElement, appName: String) throws(ScreenReadingError)
        -> AXUIElement
    {
        var windowValue: CFTypeRef?
        var status = AXUIElementCopyAttributeValue(
            appElement, kAXFocusedWindowAttribute as CFString, &windowValue)
        if status != .success {
            status = AXUIElementCopyAttributeValue(
                appElement, kAXMainWindowAttribute as CFString, &windowValue)
        }
        switch status {
        case .success:
            guard let windowValue, CFGetTypeID(windowValue) == AXUIElementGetTypeID() else {
                throw .noWindow(appName: appName)
            }
            return unsafeDowncast(windowValue, to: AXUIElement.self)
        case .cannotComplete:
            throw .appNotResponding(appName: appName)
        case .apiDisabled:
            throw .accessibilityNotTrusted
        default:
            throw .noWindow(appName: appName)
        }
    }

    /// The live element for `number` in the current table, if the table belongs to that process.
    func liveElement(number: Int, processIdentifier: pid_t) -> AXUIElement? {
        guard currentProcessIdentifier == processIdentifier,
            let handleIndex = currentTable?.handleIndexByElementNumber[number],
            handles.indices.contains(handleIndex)
        else {
            return nil
        }
        return handles[handleIndex]
    }

    static func stringAttribute(_ attributeName: String, of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attributeName as CFString, &value) == .success
        else {
            return nil
        }
        return value as? String
    }

    // MARK: - Tree walking

    private func node(for element: AXUIElement, depth: Int, walk: inout TreeWalk)
        -> AccessibilityNode
    {
        walk.nodesVisited += 1
        let handleIndex = handles.count
        handles.append(element)
        let attributes = Self.attributes(of: element)

        var children: [AccessibilityNode] = []
        if depth < ScreenReadingLimits.maximumDepth {
            for child in attributes.children {
                guard walk.canContinue else {
                    break
                }
                children.append(node(for: child, depth: depth + 1, walk: &walk))
            }
        }
        return AccessibilityNode(
            handleIndex: handleIndex,
            role: attributes.role,
            subrole: attributes.subrole,
            title: attributes.title,
            elementDescription: attributes.elementDescription,
            placeholder: attributes.placeholder,
            helpText: attributes.helpText,
            identifier: attributes.identifier,
            value: attributes.value,
            isEnabled: attributes.isEnabled,
            width: attributes.size.width,
            height: attributes.size.height,
            children: children)
    }

    /// Copies every attribute in one round trip to the app.
    private static func attributes(of element: AXUIElement) -> NodeAttributes {
        var values: CFArray?
        let status = AXUIElementCopyMultipleAttributeValues(
            element, attributeNames as CFArray, AXCopyMultipleAttributeOptions(rawValue: 0), &values
        )
        var attributes = NodeAttributes()
        guard status == .success, let values = values as? [AnyObject],
            values.count == attributeNames.count
        else {
            return attributes
        }
        for (attributeName, value) in zip(attributeNames, values) where !isErrorPlaceholder(value) {
            switch attributeName {
            case kAXRoleAttribute: attributes.role = value as? String ?? ""
            case kAXSubroleAttribute: attributes.subrole = value as? String
            case kAXTitleAttribute: attributes.title = value as? String
            case kAXDescriptionAttribute: attributes.elementDescription = value as? String
            case kAXPlaceholderValueAttribute: attributes.placeholder = value as? String
            case kAXHelpAttribute: attributes.helpText = value as? String
            case kAXIdentifierAttribute: attributes.identifier = value as? String
            case kAXValueAttribute: attributes.value = value as? String
            case kAXEnabledAttribute: attributes.isEnabled = value as? Bool ?? true
            case kAXSizeAttribute: attributes.size = size(from: value) ?? .zero
            case kAXChildrenAttribute: attributes.children = value as? [AXUIElement] ?? []
            default: break
            }
        }
        return attributes
    }

    /// Missing attributes come back as an `AXValue` of type `.axError`.
    private static func isErrorPlaceholder(_ value: AnyObject) -> Bool {
        guard CFGetTypeID(value) == AXValueGetTypeID() else {
            return false
        }
        return AXValueGetType(unsafeDowncast(value, to: AXValue.self)) == .axError
    }

    private static func size(from value: AnyObject) -> CGSize? {
        guard CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        var size = CGSize.zero
        let axValue = unsafeDowncast(value, to: AXValue.self)
        return AXValueGetValue(axValue, .cgSize, &size) ? size : nil
    }
}
