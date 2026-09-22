@testable import GlimCore

extension UIElementSnapshot {
    /// A button unless another role is given; only the label is required.
    static func fixture(
        number: Int = 1,
        role: String = "AXButton",
        subrole: String? = nil,
        label: String,
        title: String? = nil,
        elementDescription: String? = nil,
        helpText: String? = nil,
        identifier: String? = nil
    ) -> UIElementSnapshot {
        UIElementSnapshot(
            number: number,
            role: role,
            subrole: subrole,
            label: label,
            title: title,
            elementDescription: elementDescription,
            helpText: helpText,
            identifier: identifier)
    }
}
