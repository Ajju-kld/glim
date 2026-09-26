/// When Glim waits for a web page to finish loading before the next step reads it.
///
/// A click or Return in a browser starts loading a page; read at once, the window still shows
/// the old page (or a half-drawn new one), and a step such as "click the first search result"
/// would pick from the wrong page.
enum PageLoadSettle {
    /// Whether `action` in the app with `bundleIdentifier` may load a new page, so the window
    /// should be read again until the page settles.
    static func waitsForPage(
        after action: StepAction, inAppWithBundleIdentifier bundleIdentifier: String
    ) -> Bool {
        guard WebBrowsers.isBrowser(bundleIdentifier: bundleIdentifier) else {
            return false
        }
        switch action {
        case .click:
            return true
        case .pressKey(_, let key):
            return key == .returnKey
        case .openApp, .switchApp, .quitApp, .typeText, .scroll, .moveWindow, .minimizeWindow,
            .restoreWindow, .speak:
            return false
        }
    }

    /// Whether `latest` shows a finished page: it differs from the window before the action
    /// (the page did change) and matches the read just before it (it stopped changing).
    static func hasSettled(
        _ latest: ScreenSnapshot, previous: ScreenSnapshot?, before: ScreenSnapshot
    ) -> Bool {
        guard let previous else {
            return false
        }
        return looksTheSame(latest, previous) && !looksTheSame(latest, before)
    }

    private static func looksTheSame(_ first: ScreenSnapshot, _ second: ScreenSnapshot) -> Bool {
        first.table == second.table && first.windowTitle == second.windowTitle
    }
}
