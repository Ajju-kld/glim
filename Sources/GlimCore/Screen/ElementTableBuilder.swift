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
    /// Business rule: the title bar's own buttons close, minimize or zoom the window. They are
    /// never offered, so the model can't pick them.
    private static let windowButtonSubroles: Set<String> = [
        "AXCloseButton", "AXMinimizeButton", "AXZoomButton", "AXFullScreenButton",
    ]
    /// Business rule: list rows and cells give way to buttons and fields when a window has more
    /// controls than the table holds (Notes lists every note before its toolbar).
    private static let lowPriorityRoles: Set<String> = ["AXRow", "AXCell"]

    private struct Candidate {
        let node: AccessibilityNode
        let label: String
        let readingPosition: Int
    }

    /// Creates a builder.
    public init() {}

    /// Builds the table for `window`, walking its tree in reading order. When there are more
    /// controls than the table holds, buttons and fields are kept before list rows and cells;
    /// the table stays in reading order either way.
    public func build(from window: AccessibilityNode) -> ElementTable {
        var candidates: [Candidate] = []
        var readableText = ReadableTextCollector()
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
            candidates.append(
                Candidate(node: node, label: label, readingPosition: candidates.count))
        }

        let limit = ScreenReadingLimits.maximumListedElements
        let wasTruncated = candidates.count > limit
        let keptCandidates =
            wasTruncated ? Self.prioritized(candidates, limit: limit) : candidates
        var elements: [UIElementSnapshot] = []
        var handleIndexByElementNumber: [Int: Int] = [:]
        for candidate in keptCandidates {
            let node = candidate.node
            let label = candidate.label
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

    /// Up to `limit` candidates: buttons and fields first, then rows and cells, in reading order.
    private static func prioritized(_ candidates: [Candidate], limit: Int) -> [Candidate] {
        let (rows, controls) = candidates.reduce(into: ([Candidate](), [Candidate]())) {
            groups, candidate in
            if lowPriorityRoles.contains(candidate.node.role) {
                groups.0.append(candidate)
            } else {
                groups.1.append(candidate)
            }
        }
        let kept = Array((controls + rows).prefix(limit))
        return kept.sorted { $0.readingPosition < $1.readingPosition }
    }

    /// The label given to a text field or area that has no name of its own, such as Notes'
    /// note body. It names the kind of field, never its contents.
    public static func untitledLabel(for role: String) -> String {
        switch role {
        case "AXTextArea": "Untitled text area"
        case "AXTextField": "Untitled text field"
        case "AXComboBox": "Untitled combo box"
        default: "Untitled field"
        }
    }

    /// The label for an actionable control, or nil when the node isn't one Glim may list.
    static func label(for node: AccessibilityNode) -> String? {
        let isClickable = ElementRoles.clickableRoles.contains(node.role)
        let isTextEntry = ElementRoles.textEntryRoles.contains(node.role)
        guard isClickable || isTextEntry, node.isEnabled, node.width > 0, node.height > 0,
            !windowButtonSubroles.contains(node.subrole ?? "")
        else {
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
            ? firstStaticText(in: node.children, remainingDepth: labelSearchDepth)
            : untitledLabel(for: node.role)
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
