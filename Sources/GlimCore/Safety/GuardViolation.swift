/// Why a guard stopped a task. Every violation shows the red guard popup and stops the task;
/// it is never retried.
public enum GuardViolation: Error, Sendable, Equatable {
    case killSwitchTripped
    case watchdogMissing
    case blockedByTier(appName: String, tier: TrustTier, action: ActionKind)
    case notInPlan(planned: String, proposed: String)
    case unknownTarget(description: String)
    case secureField(elementLabel: String)
    case textMismatch
    case textTooLong(limit: Int)
    case unsafeText
    case emptyPlan
    case limitReached(LimitViolation)
    case forbiddenAction(matchedPhrase: String, elementLabel: String)
    case unverifiedApp(appName: String)
    case changedWhileWaiting(description: String)

    /// Short headline for the guard popup.
    public var title: String {
        switch self {
        case .killSwitchTripped: "Glim is stopped"
        case .watchdogMissing: "Kill-switch watchdog is not running"
        case .blockedByTier: "This app does not allow that"
        case .notInPlan: "Not in the approved plan"
        case .unknownTarget: "Target not found"
        case .secureField: "Password field"
        case .textMismatch: "Text differs from the plan"
        case .textTooLong: "Text is too long"
        case .unsafeText: "Text contains control characters"
        case .emptyPlan: "Empty plan"
        case .limitReached: "Safety limit reached"
        case .forbiddenAction: "Forbidden action"
        case .unverifiedApp: "App signature not verified"
        case .changedWhileWaiting: "The screen changed while you decided"
        }
    }

    /// One sentence saying what the AI tried and why it was stopped.
    public var explanation: String {
        switch self {
        case .killSwitchTripped:
            "Glim is stopped. Click Re-arm to allow actions again."
        case .watchdogMissing:
            "The watchdog that owns ⌃⌥⌘K is not running, so actions are off."
        case .blockedByTier(let appName, let tier, let action):
            "\(appName) is \(tier.displayName), which does not allow “\(action.displayName)”."
        case .notInPlan(let planned, let proposed):
            "The plan said “\(planned)”, but the AI tried “\(proposed)”."
        case .unknownTarget(let description):
            "Could not find “\(description)”."
        case .secureField(let elementLabel):
            "“\(elementLabel)” is a password field. Glim never touches password fields."
        case .textMismatch:
            "The text to type differs from the text you approved."
        case .textTooLong(let limit):
            "The text is longer than \(limit) characters."
        case .unsafeText:
            "The text contains a line break, tab or control character, which acts like a key press."
        case .emptyPlan:
            "The plan has no steps."
        case .limitReached(let limitViolation):
            limitViolation.explanation
        case .forbiddenAction(let matchedPhrase, let elementLabel):
            "“\(elementLabel)” matches the forbidden phrase “\(matchedPhrase)”."
        case .unverifiedApp(let appName):
            "\(appName) isn't signed by an Apple-issued certificate under its own identifier, so Glim won't open it."
        case .changedWhileWaiting(let description):
            "“\(description)” changed while Glim waited for you, so it stopped instead of acting on something new."
        }
    }
}
