import Testing

@testable import GlimCore

struct ElementRolesTests {
    /// Plans say "Click the address bar"; clicking a field puts the cursor in it.
    @Test(arguments: ["AXTextField", "AXTextArea", "AXComboBox"])
    func textFieldsCanBeClicked(role: String) {
        #expect(ElementRoles.role(role, isCompatibleWith: .click))
    }

    @Test func passwordFieldsAreNeverOfferedForAClick() {
        let passwordField = UIElementSnapshot.fixture(
            number: 1, role: "AXTextField", subrole: "AXSecureTextField", label: "Password")
        let searchField = UIElementSnapshot.fixture(number: 2, role: "AXTextField", label: "Search")

        #expect(
            ElementRoles.candidates(in: [passwordField, searchField], for: .click) == [searchField])
    }

    @Test(arguments: ["AXTextField", "AXTextArea", "AXComboBox"])
    func clickingAFieldFocusesIt(role: String) {
        #expect(ElementRoles.clickMethod(forRole: role) == .focus)
    }

    @Test(arguments: ["AXButton", "AXLink", "AXCell", "AXTab"])
    func clickingAControlPressesIt(role: String) {
        #expect(ElementRoles.clickMethod(forRole: role) == .press)
    }
}
