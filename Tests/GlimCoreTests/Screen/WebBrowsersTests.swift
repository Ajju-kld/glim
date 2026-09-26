import Testing

@testable import GlimCore

struct WebBrowsersTests {
    @Test(arguments: [
        "com.google.Chrome", "com.brave.Browser", "com.apple.Safari", "org.mozilla.firefox",
    ])
    func knownBrowsersAreBrowsers(bundleIdentifier: String) {
        #expect(WebBrowsers.isBrowser(bundleIdentifier: bundleIdentifier))
    }

    @Test func otherAppsAreNot() {
        #expect(!WebBrowsers.isBrowser(bundleIdentifier: "com.spotify.client"))
    }

    @Test func textFieldOutsideAnyWebPageIsTheAddressBar() {
        #expect(
            WebBrowsers.isAddressBar(
                focusedRole: "AXTextField", ancestorRoles: ["AXGroup", "AXToolbar", "AXWindow"]))
    }

    /// A page can name its own text box "Address and search bar"; only where it sits counts.
    @Test func textFieldInsideAWebPageIsNot() {
        #expect(
            !WebBrowsers.isAddressBar(
                focusedRole: "AXTextField",
                ancestorRoles: ["AXGroup", "AXWebArea", "AXScrollArea", "AXWindow"]))
    }

    @Test func buttonOutsideTheWebPageIsNot() {
        #expect(
            !WebBrowsers.isAddressBar(focusedRole: "AXButton", ancestorRoles: ["AXToolbar"]))
    }

    /// Nothing read above the control means Glim can't tell where it is, so it isn't trusted.
    @Test func controlWithUnknownSurroundingsIsNot() {
        #expect(!WebBrowsers.isAddressBar(focusedRole: "AXTextField", ancestorRoles: []))
    }
}
