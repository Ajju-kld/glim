/// Which accessibility roles each action can target.
public enum ElementRoles {
    /// How a click acts on its control.
    public enum ClickMethod: Sendable, Equatable {
        /// Press the control, like a mouse click on a button.
        case press
        /// Put the cursor in the field; pressing a text field does nothing in most apps.
        case focus
    }

    /// Business rule: controls a click may press.
    public static let clickableRoles: Set<String> = [
        "AXButton", "AXMenuItem", "AXMenuButton", "AXPopUpButton", "AXCheckBox", "AXRadioButton",
        "AXLink", "AXCell", "AXRow", "AXDisclosureTriangle", "AXTab",
    ]

    /// Business rule: fields Glim may type into. Password fields are deliberately absent.
    public static let textEntryRoles: Set<String> = ["AXTextField", "AXTextArea", "AXComboBox"]

    /// Whether an element with `role` can be the target of `kind`.
    public static func role(_ role: String, isCompatibleWith kind: ActionKind) -> Bool {
        switch kind {
        // A plan may say "Click the address bar": clicking a field puts the cursor in it.
        case .click: clickableRoles.contains(role) || textEntryRoles.contains(role)
        case .typeText: textEntryRoles.contains(role)
        case .openApp, .switchApp, .quitApp, .pressKey, .scroll, .moveWindow, .minimizeWindow,
            .restoreWindow, .speak:
            false
        }
    }

    /// How a click acts on a control with `role`: fields are focused, everything else pressed.
    public static func clickMethod(forRole role: String) -> ClickMethod {
        textEntryRoles.contains(role) ? .focus : .press
    }

    /// The elements of `table` that `kind` may target.
    public static func candidates(
        in table: [UIElementSnapshot], for kind: ActionKind
    ) -> [UIElementSnapshot] {
        table.filter { element in
            !element.isSecureTextField && role(element.role, isCompatibleWith: kind)
        }
    }

    /// A short role name for prompts, such as "Button" for `AXButton`.
    public static func displayName(of role: String) -> String {
        role.hasPrefix("AX") ? String(role.dropFirst(2)) : role
    }
}
