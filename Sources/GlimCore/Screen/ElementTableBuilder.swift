import Foundation

/// Turns an accessibility tree into the numbered table the model sees.
///
/// Only enabled, visible, labelled controls that a click or typing step can target are listed.
/// Password fields never appear — not in the table and not in the readable text.
public struct ElementTableBuilder: Sendable {
    private static let readableTextRoles: Set<String> = [
        "AXStaticText", "AXTextArea", "AXTextField", "AXHeading",
    ]
    private static let labelSearchDepth = 2

    /// Creates a builder.
    public init() {}

    /// Builds the table for `window`, walking its tree in reading order.
    public func build(from window: AccessibilityNode) -> ElementTable {
        var elements: [UIElementSnapshot] = []
        var handleIndexByElementNumber: [Int: Int] = [:]
        var readableText = ReadableTextCollector()
        var wasTruncated = false
        var nodesToVisit = [window]

        while let node = nodesToVisit.popLast() {
            nodesToVisit.append(contentsOf: node.children.reversed())
            guard !node.isSecureTextField else {
                continue
            }
            if Self.readableTextRoles.contains(node.role), let text = Self.nonBlank(node.value) {
                readableText.append(text)
            }
            guard let label = Self.label(for: node) else {
                continue
            }
            guard elements.count < ScreenReadingLimits.maximumListedElements else {
                wasTruncated = true
                continue
            }
            let elementNumber = elements.count + 1
            elements.append(
                UIElementSnapshot(
                    number: elementNumber,
                    role: node.role,
                    subrole: node.subrole,
                    label: label,
                    title: node.title,
                    elementDescription: node.elementDescription,
                    helpText: node.helpText,
                    identifier: node.identifier,
                    value: node.value))
            handleIndexByElementNumber[elementNumber] = node.handleIndex
        }
        return ElementTable(
            elements: elements,
            handleIndexByElementNumber: handleIndexByElementNumber,
            readableText: readableText.text,
            wasTruncated: wasTruncated)
    }

    /// The label for an actionable control, or nil when the node isn't one Glim may list.
    private static func label(for node: AccessibilityNode) -> String? {
        let isClickable = ElementRoles.clickableRoles.contains(node.role)
        let isTextEntry = ElementRoles.textEntryRoles.contains(node.role)
        guard isClickable || isTextEntry, node.isEnabled, node.width > 0, node.height > 0 else {
            return nil
        }
        let ownLabel = [node.title, node.elementDescription, node.placeholder, node.helpText]
            .lazy
            .compactMap(nonBlank)
            .first
        if let ownLabel {
            return ownLabel
        }
        return isClickable
            ? firstStaticText(in: node.children, remainingDepth: labelSearchDepth) : nil
    }

    /// Buttons drawn by some frameworks carry their text in a child static text.
    private static func firstStaticText(
        in children: [AccessibilityNode], remainingDepth: Int
    ) -> String? {
        guard remainingDepth > 0 else {
            return nil
        }
        for child in children {
            if child.role == "AXStaticText", let text = nonBlank(child.value) {
                return text
            }
            if let text = firstStaticText(in: child.children, remainingDepth: remainingDepth - 1) {
                return text
            }
        }
        return nil
    }

    private static func nonBlank(_ text: String?) -> String? {
        guard let trimmedText = text?.trimmingCharacters(in: .whitespacesAndNewlines),
            !trimmedText.isEmpty
        else {
            return nil
        }
        return trimmedText
    }
}

/// Collects screen text up to the readable-text limit.
private struct ReadableTextCollector {
    private(set) var text = ""

    mutating func append(_ part: String) {
        let separator = text.isEmpty ? "" : "\n"
        let remainingRoom =
            ScreenReadingLimits.maximumReadableTextLength - text.count - separator.count
        guard remainingRoom > 0 else {
            return
        }
        text += separator + String(part.prefix(remainingRoom))
    }
}
