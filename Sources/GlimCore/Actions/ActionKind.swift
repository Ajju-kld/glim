/// Every kind of action Glim can perform.
///
/// Anything not listed here cannot be expressed in a plan, so it cannot be executed.
public enum ActionKind: String, Sendable, Codable, CaseIterable {
    case openApp
    case switchApp
    case quitApp
    case click
    case typeText
    case pressKey
    case scroll
    case moveWindow
    case minimizeWindow
    case restoreWindow
    case speak

    /// Whether the model must pick an on-screen element before this action can run.
    public var needsTargetElement: Bool {
        self == .click || self == .typeText
    }

    /// Lowercase words used in popups and logs, such as "type text".
    public var displayName: String {
        switch self {
        case .openApp: "open app"
        case .switchApp: "switch to app"
        case .quitApp: "quit app"
        case .click: "click"
        case .typeText: "type text"
        case .pressKey: "press key"
        case .scroll: "scroll"
        case .moveWindow: "move window"
        case .minimizeWindow: "minimize window"
        case .restoreWindow: "restore window"
        case .speak: "speak"
        }
    }
}
