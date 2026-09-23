import ApplicationServices
import Foundation

/// The live bridge to the macOS Accessibility API, for reading windows and acting on them.
///
/// Every `AXUIElement` stays inside this actor: tables are handed out as plain values, and an
/// action names an element by number. All calls run off the main thread with a short
/// messaging timeout, so a frozen app can't block Glim or the kill switch.
public actor AccessibilityService: ScreenReading {
    struct NodeAttributes {
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

    /// Creates the service and sets the one-second messaging timeout for every Accessibility
    /// call this process makes. Setting it on an app element covers only that element, so the
    /// system-wide element is where it must go.
    public init() {
        AXUIElementSetMessagingTimeout(
            AXUIElementCreateSystemWide(), ScreenReadingLimits.messagingTimeoutSeconds)
    }

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
        let rootNode = readTree(from: window)
        let table = ElementTableBuilder().build(from: rootNode)
        currentTable = table
        currentProcessIdentifier = processIdentifier
        return ScreenSnapshot(
            app: app, windowTitle: Self.stringAttribute(kAXTitleAttribute, of: window), table: table
        )
    }

    /// What pressing Return would activate in `app`: the focused control and the focused window's
    /// default button. Empty when nothing can be read (the gate then still asks the person).
    public func returnKeyTargetTexts(in app: ResolvedApp) -> [String] {
        guard Self.isTrusted, let processIdentifier = app.processIdentifier else {
            return []
        }
        let appElement = applicationElement(for: processIdentifier)
        var candidates: [AXUIElement] = []
        if let focusedElement = Self.elementAttribute(kAXFocusedUIElementAttribute, of: appElement)
        {
            candidates.append(focusedElement)
        }
        do {
            let window = try focusedWindow(of: appElement, appName: app.identity.displayName)
            if let defaultButton = Self.elementAttribute(kAXDefaultButtonAttribute, of: window) {
                candidates.append(defaultButton)
            }
        } catch {
            // No readable window means no default button; the focused control (if any) remains.
        }
        var texts: [String] = []
        for candidate in candidates {
            let node = shallowNode(for: candidate)
            let nodeTexts = [
                ElementTableBuilder.label(for: node), node.title, node.elementDescription,
                node.helpText,
            ]
            for text in nodeTexts.compactMap({ $0 }) where !text.isEmpty && !texts.contains(text) {
                texts.append(text)
            }
        }
        return texts
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

    /// Reads a live element and a couple of levels of its children, without touching the
    /// current table's handles — for re-checking a control right before acting on it.
    func shallowNode(for element: AXUIElement, remainingDepth: Int = 2) -> AccessibilityNode {
        let attributes = Self.attributes(of: element)
        let children =
            remainingDepth > 0
            ? attributes.children.map { shallowNode(for: $0, remainingDepth: remainingDepth - 1) }
            : []
        return AccessibilityNode(
            handleIndex: 0,
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

    static func elementAttribute(_ attributeName: String, of element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attributeName as CFString, &value) == .success,
            let value, CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return nil
        }
        return unsafeDowncast(value, to: AXUIElement.self)
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

    /// Reads the window's tree level by level within the node and time budget, so controls near
    /// the top (the toolbar) are read before long lists deep in the tree use up the budget.
    private func readTree(from window: AXUIElement) -> AccessibilityNode {
        let deadline = ContinuousClock.now + ScreenReadingLimits.walkTimeBudget
        let result = BreadthFirstWalk.walk(
            from: window, maximumDepth: ScreenReadingLimits.maximumDepth,
            shouldContinue: { visitedCount in
                visitedCount < ScreenReadingLimits.maximumNodes && ContinuousClock.now < deadline
            },
            visit: { element in
                let attributes = Self.attributes(of: element)
                return (details: attributes, children: attributes.children)
            })
        let firstHandleIndex = handles.count
        handles.append(contentsOf: result.elements)
        let handleIndices = result.elements.indices.map { firstHandleIndex + $0 }
        return assembledNode(
            at: 0, childIndices: result.childIndices, attributes: result.details,
            handleIndices: handleIndices)
    }

    private func assembledNode(
        at index: Int, childIndices: [[Int]], attributes: [NodeAttributes], handleIndices: [Int]
    ) -> AccessibilityNode {
        let nodeAttributes = attributes[index]
        return AccessibilityNode(
            handleIndex: handleIndices[index],
            role: nodeAttributes.role,
            subrole: nodeAttributes.subrole,
            title: nodeAttributes.title,
            elementDescription: nodeAttributes.elementDescription,
            placeholder: nodeAttributes.placeholder,
            helpText: nodeAttributes.helpText,
            identifier: nodeAttributes.identifier,
            value: nodeAttributes.value,
            isEnabled: nodeAttributes.isEnabled,
            width: nodeAttributes.size.width,
            height: nodeAttributes.size.height,
            children: childIndices[index].map { childIndex in
                assembledNode(
                    at: childIndex, childIndices: childIndices, attributes: attributes,
                    handleIndices: handleIndices)
            })
    }

    /// Copies every attribute in one round trip to the app.
    static func attributes(of element: AXUIElement) -> NodeAttributes {
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
