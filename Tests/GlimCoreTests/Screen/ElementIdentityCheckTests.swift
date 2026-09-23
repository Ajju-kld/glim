import Testing

@testable import GlimCore

struct ElementIdentityCheckTests {
    /// The builder labels this button by its description, "Reply to Ana".
    let snapshot = UIElementSnapshot(
        number: 1, role: "AXButton", label: "Reply to Ana", title: nil,
        elementDescription: "Reply to Ana",
        helpText: "Reply", identifier: "reply-button", value: nil)

    func liveNode(
        title: String? = nil, elementDescription: String? = "Reply to Ana",
        helpText: String? = "Reply",
        identifier: String? = "reply-button", childText: String = "Reply", isEnabled: Bool = true,
        role: String = "AXButton", subrole: String? = nil, value: String? = nil
    ) -> AccessibilityNode {
        AccessibilityNode(
            handleIndex: 0, role: role, subrole: subrole, title: title,
            elementDescription: elementDescription, placeholder: nil, helpText: helpText,
            identifier: identifier, value: value, isEnabled: isEnabled, width: 40, height: 20,
            children: [.fixture(handleIndex: 1, role: "AXStaticText", value: childText)])
    }

    @Test func unchangedControlMatches() {
        #expect(ElementIdentityCheck.liveNode(liveNode(), isSameControlAs: snapshot))
    }

    @Test func changedValueStillMatches() {
        #expect(ElementIdentityCheck.liveNode(liveNode(value: "draft"), isSameControlAs: snapshot))
    }

    @Test func changedDescriptionDoesNotMatch() {
        #expect(
            !ElementIdentityCheck.liveNode(
                liveNode(elementDescription: "Delete"), isSameControlAs: snapshot))
    }

    @Test func changedHelpOrIdentifierDoesNotMatch() {
        #expect(
            !ElementIdentityCheck.liveNode(
                liveNode(helpText: "Delete message"), isSameControlAs: snapshot))
        #expect(
            !ElementIdentityCheck.liveNode(
                liveNode(identifier: "delete-button"), isSameControlAs: snapshot))
    }

    @Test func labelFromChildTextIsRechecked() {
        let rowSnapshot = UIElementSnapshot(number: 3, role: "AXRow", label: "Lunch on Friday")
        let changedRow = AccessibilityNode(
            handleIndex: 0, role: "AXRow", subrole: nil, title: nil, elementDescription: nil,
            placeholder: nil, helpText: nil, identifier: nil, value: nil, isEnabled: true,
            width: 300,
            height: 40,
            children: [.fixture(handleIndex: 1, role: "AXStaticText", value: "Delete account")])

        #expect(!ElementIdentityCheck.liveNode(changedRow, isSameControlAs: rowSnapshot))
    }

    @Test func disabledOrSecureControlDoesNotMatch() {
        #expect(
            !ElementIdentityCheck.liveNode(liveNode(isEnabled: false), isSameControlAs: snapshot))
        #expect(
            !ElementIdentityCheck.liveNode(
                liveNode(subrole: "AXSecureTextField"), isSameControlAs: snapshot))
    }

    @Test func snapshotsIdentifyTheSameControlRegardlessOfValue() {
        let withValue = UIElementSnapshot(
            number: 1, role: "AXButton", label: "Reply to Ana", elementDescription: "Reply to Ana",
            helpText: "Reply", identifier: "reply-button", value: "changed")

        #expect(withValue.identifiesSameControl(as: snapshot))
        #expect(
            !UIElementSnapshot.fixture(number: 2, label: "Reply to Ana").identifiesSameControl(
                as: snapshot))
    }
}
