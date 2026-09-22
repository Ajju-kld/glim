/// The only keys Glim may press.
///
/// Delete, Forward Delete and every modifier shortcut are deliberately absent, so a plan can
/// never erase text or trigger app shortcuts by key press.
public enum AllowedKey: String, Sendable, Codable, CaseIterable {
    case tab
    case escape
    case upArrow
    case downArrow
    case leftArrow
    case rightArrow
    case returnKey

    /// Name shown in plans and popups.
    public var displayName: String {
        switch self {
        case .tab: "Tab"
        case .escape: "Escape"
        case .upArrow: "Up Arrow"
        case .downArrow: "Down Arrow"
        case .leftArrow: "Left Arrow"
        case .rightArrow: "Right Arrow"
        case .returnKey: "Return"
        }
    }
}
