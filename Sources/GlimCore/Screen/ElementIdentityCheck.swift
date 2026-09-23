/// Confirms, right before acting, that a live control is still the one the table described.
enum ElementIdentityCheck {
    /// Whether the live node still matches the snapshot: same role and subrole, still enabled,
    /// visible and not a password field, the same label (recomputed the same way, including
    /// labels taken from child text), and the same title, description, help and identifier.
    /// The value may differ — it is content, not identity.
    static func liveNode(_ node: AccessibilityNode, isSameControlAs snapshot: UIElementSnapshot)
        -> Bool
    {
        guard node.role == snapshot.role, node.subrole == snapshot.subrole, !node.isSecureTextField,
            let liveLabel = ElementTableBuilder.label(for: node), liveLabel == snapshot.label
        else {
            return false
        }
        return node.title == snapshot.title
            && node.elementDescription == snapshot.elementDescription
            && node.helpText == snapshot.helpText && node.identifier == snapshot.identifier
    }
}
