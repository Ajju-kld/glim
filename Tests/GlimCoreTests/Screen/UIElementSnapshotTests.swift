import Testing

@testable import GlimCore

struct UIElementSnapshotTests {
    @Test func secureTextFieldIsDetectedByRole() {
        let passwordField = UIElementSnapshot.fixture(role: "AXSecureTextField", label: "Password")

        #expect(passwordField.isSecureTextField)
    }

    @Test func secureTextFieldIsDetectedBySubrole() {
        let passwordField = UIElementSnapshot.fixture(
            role: "AXTextField", subrole: "AXSecureTextField", label: "Password")

        #expect(passwordField.isSecureTextField)
    }

    @Test func ordinaryButtonIsNotSecure() {
        #expect(!UIElementSnapshot.fixture(label: "New Note").isSecureTextField)
    }

    @Test func describingTextsSkipMissingValuesAndExcludeContent() {
        let element = UIElementSnapshot(
            number: 1, role: "AXButton", label: "Trash", elementDescription: "Move to Trash",
            value: "typed content")

        #expect(element.describingTexts == ["Trash", "Move to Trash"])
    }
}
