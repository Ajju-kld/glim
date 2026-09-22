/// One step of a plan, as approved by the person.
///
/// Every step that touches an app names that app, so screening can check the app's trust tier
/// before the plan is shown, and the gate can check that the step runs in that same app.
public enum StepAction: Sendable, Hashable {
    case openApp(appName: String)
    case switchApp(appName: String)
    case quitApp(appName: String)
    case click(appName: String, target: String)
    case typeText(appName: String, target: String, text: String)
    case pressKey(appName: String, key: AllowedKey)
    case scroll(appName: String, direction: ScrollDirection)
    case moveWindow(appName: String, preset: WindowPreset)
    case minimizeWindow(appName: String)
    case restoreWindow(appName: String)
    case speak(text: String)

    /// The kind of action this step performs.
    public var kind: ActionKind {
        switch self {
        case .openApp: .openApp
        case .switchApp: .switchApp
        case .quitApp: .quitApp
        case .click: .click
        case .typeText: .typeText
        case .pressKey: .pressKey
        case .scroll: .scroll
        case .moveWindow: .moveWindow
        case .minimizeWindow: .minimizeWindow
        case .restoreWindow: .restoreWindow
        case .speak: .speak
        }
    }

    /// The app this step acts on, or nil for `speak`, which touches no app.
    public var appName: String? {
        switch self {
        case .openApp(let appName), .switchApp(let appName), .quitApp(let appName),
            .click(let appName, _), .typeText(let appName, _, _), .pressKey(let appName, _),
            .scroll(let appName, _), .moveWindow(let appName, _), .minimizeWindow(let appName),
            .restoreWindow(let appName):
            appName
        case .speak:
            nil
        }
    }

    /// The person-readable description of the control to act on, for `click` and `typeText`.
    public var targetDescription: String? {
        switch self {
        case .click(_, let target), .typeText(_, let target, _):
            target
        case .openApp, .switchApp, .quitApp, .pressKey, .scroll, .moveWindow, .minimizeWindow,
            .restoreWindow, .speak:
            nil
        }
    }

    /// The exact text approved for typing. The model can never change it after approval.
    public var approvedText: String? {
        switch self {
        case .typeText(_, _, let text):
            text
        case .openApp, .switchApp, .quitApp, .click, .pressKey, .scroll, .moveWindow,
            .minimizeWindow, .restoreWindow, .speak:
            nil
        }
    }

    /// One line shown in the plan approval panel and the audit log.
    public var summary: String {
        switch self {
        case .openApp(let appName):
            "Open \(appName)"
        case .switchApp(let appName):
            "Switch to \(appName)"
        case .quitApp(let appName):
            "Quit \(appName)"
        case .click(let appName, let target):
            "Click “\(target)” in \(appName)"
        case .typeText(let appName, let target, let text):
            "Type “\(text)” into “\(target)” in \(appName)"
        case .pressKey(let appName, let key):
            "Press \(key.displayName) in \(appName)"
        case .scroll(let appName, let direction):
            "Scroll \(direction.rawValue) in \(appName)"
        case .moveWindow(let appName, let preset):
            "Move \(appName) window: \(preset.displayName)"
        case .minimizeWindow(let appName):
            "Minimize \(appName)"
        case .restoreWindow(let appName):
            "Restore \(appName)"
        case .speak(let text):
            "Say “\(text)”"
        }
    }
}
