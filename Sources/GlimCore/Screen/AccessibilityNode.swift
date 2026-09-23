/// One node of an app's accessibility tree, copied into a plain value.
public struct AccessibilityNode: Sendable {
    /// Index of the live element in the reader's handle list.
    public let handleIndex: Int
    /// Accessibility role.
    public let role: String
    /// Accessibility subrole.
    public let subrole: String?
    /// Title attribute.
    public let title: String?
    /// Description attribute.
    public let elementDescription: String?
    /// Placeholder text of an empty field.
    public let placeholder: String?
    /// Help text (tooltip).
    public let helpText: String?
    /// Developer-assigned identifier.
    public let identifier: String?
    /// Current value, when it is text.
    public let value: String?
    /// Whether the control is enabled.
    public let isEnabled: Bool
    /// Width in points.
    public let width: Double
    /// Height in points.
    public let height: Double
    /// Child nodes in reading order.
    public let children: [AccessibilityNode]

    /// Creates a node.
    public init(
        handleIndex: Int,
        role: String,
        subrole: String?,
        title: String?,
        elementDescription: String?,
        placeholder: String?,
        helpText: String?,
        identifier: String?,
        value: String?,
        isEnabled: Bool,
        width: Double,
        height: Double,
        children: [AccessibilityNode]
    ) {
        self.handleIndex = handleIndex
        self.role = role
        self.subrole = subrole
        self.title = title
        self.elementDescription = elementDescription
        self.placeholder = placeholder
        self.helpText = helpText
        self.identifier = identifier
        self.value = value
        self.isEnabled = isEnabled
        self.width = width
        self.height = height
        self.children = children
    }

    /// Whether the node is a password-style field.
    var isSecureTextField: Bool {
        role == UIElementSnapshot.secureTextRole || subrole == UIElementSnapshot.secureTextRole
    }
}
