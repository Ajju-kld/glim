/// Confirms, right before acting, that a live control is still the one the table described.
enum ElementIdentityCheck {
    /// Whether the live node still matches the snapshot: same role and subrole, still enabled,
    /// visible and not a password field, the same label (recomputed the same way, including
    /// labels taken from child text), and the same title, description, help and identifier.
    /// The value may differ — it is content, not identity.
    static func liveNode(_ node: AccessibilityNode, isSameControlAs snapshot: UIElementSnapshot)
        -> Bool
    {
        difference(node, from: snapshot) == nil
    }

    /// What makes the live node a different control from the snapshot, in words for the log,
    /// or nil when it is the same control.
    static func difference(_ node: AccessibilityNode, from snapshot: UIElementSnapshot) -> String? {
        guard !node.role.isEmpty else {
            return "the control is gone"
        }
        if let change = change("role", from: snapshot.role, to: node.role)
            ?? change("subrole", from: snapshot.subrole, to: node.subrole)
        {
            return change
        }
        if node.isSecureTextField {
            return "it is a password field now"
        }
        guard node.isEnabled else {
            return "it is greyed out now"
        }
        return change("label", from: snapshot.label, to: ElementTableBuilder.label(for: node))
            ?? change("title", from: snapshot.title, to: node.title)
            ?? change("description", from: snapshot.elementDescription, to: node.elementDescription)
            ?? change("help text", from: snapshot.helpText, to: node.helpText)
            ?? change("identifier", from: snapshot.identifier, to: node.identifier)
    }

    private static func change(_ attributeName: String, from before: String?, to after: String?)
        -> String?
    {
        guard before != after else {
            return nil
        }
        return "\(attributeName) “\(before ?? "none")” became “\(after ?? "none")”"
    }
}
