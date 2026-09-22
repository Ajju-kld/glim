/// One actionable control from the front window, as numbered in the element table.
///
/// Snapshots are plain values copied out of the Accessibility API, so safety checks never
/// touch live interface objects.
public struct UIElementSnapshot: Sendable, Hashable {
    /// Accessibility role and subrole that hide typed characters, such as password fields.
    static let secureTextRole = "AXSecureTextField"

    /// Position in the element table, starting at 1. The model answers with this number.
    public let number: Int
    /// Accessibility role, such as `AXButton` or `AXTextField`.
    public let role: String
    /// Accessibility subrole, when the app provides one.
    public let subrole: String?
    /// The best person-readable name for the control.
    public let label: String
    /// The control's title attribute.
    public let title: String?
    /// The control's accessibility description.
    public let elementDescription: String?
    /// The control's help text (tooltip).
    public let helpText: String?
    /// The developer-assigned accessibility identifier.
    public let identifier: String?
    /// The control's current value, such as the text in a field.
    public let value: String?

    /// Creates a snapshot.
    public init(
        number: Int,
        role: String,
        subrole: String? = nil,
        label: String,
        title: String? = nil,
        elementDescription: String? = nil,
        helpText: String? = nil,
        identifier: String? = nil,
        value: String? = nil
    ) {
        self.number = number
        self.role = role
        self.subrole = subrole
        self.label = label
        self.title = title
        self.elementDescription = elementDescription
        self.helpText = helpText
        self.identifier = identifier
        self.value = value
    }

    /// Whether this is a password-style field. Glim never clicks or types into these.
    public var isSecureTextField: Bool {
        role == Self.secureTextRole || subrole == Self.secureTextRole
    }

    /// Every text that describes what this control does, used for risk checks.
    ///
    /// The value is excluded: it is content (possibly written by someone else), not a
    /// description of the control.
    public var describingTexts: [String] {
        [label, title, elementDescription, helpText, identifier].compactMap { $0 }
    }
}
