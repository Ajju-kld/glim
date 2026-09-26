/// Web browsers, and how to tell their own address bar from a text box on a web page.
public enum WebBrowsers {
    /// Business rule: browsers Glim knows. Chrome-family browsers come from ``ChromiumKind``;
    /// Safari and Firefox are added here.
    static let bundleIdentifiers: Set<String> = ChromiumKind.chromeBrowserBundleIdentifiers
        .union(["com.apple.Safari", "com.apple.SafariTechnologyPreview", "org.mozilla.firefox"])

    /// Business rule: roles a browser's address bar has.
    static let addressBarRoles: Set<String> = ["AXTextField", "AXComboBox"]

    /// The role that holds a web page's content. Everything a page draws sits inside it.
    static let webPageRole = "AXWebArea"

    /// Whether the app with `bundleIdentifier` is a known web browser.
    public static func isBrowser(bundleIdentifier: String) -> Bool {
        bundleIdentifiers.contains(bundleIdentifier)
    }

    /// Whether the focused control is the browser's own address bar: a text field with no web
    /// page among the elements above it. A page can label its own text box "Address and search
    /// bar", so where the control sits decides, never its name. When nothing above the control
    /// could be read, it is not trusted as the address bar.
    ///
    /// - Parameters:
    ///   - focusedRole: The focused control's role.
    ///   - ancestorRoles: The roles of the elements above it, nearest first.
    /// - Returns: True only for a text field with readable surroundings and no web page above it.
    public static func isAddressBar(focusedRole: String, ancestorRoles: [String]) -> Bool {
        addressBarRoles.contains(focusedRole) && !ancestorRoles.isEmpty
            && !ancestorRoles.contains(webPageRole)
    }
}
