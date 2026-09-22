import Foundation

/// Limits for reading a window, so a huge or unresponsive app can't stall Glim.
public enum ScreenReadingLimits {
    /// Tunable: deepest level of the accessibility tree that is walked.
    public static let maximumDepth = 25
    /// Tunable: most accessibility nodes visited per snapshot.
    public static let maximumNodes = 2_000
    /// Business rule: most controls offered to the model in one table.
    public static let maximumListedElements = 80
    /// Tunable: most characters of screen text collected for answering questions.
    public static let maximumReadableTextLength = 4_000
    /// Tunable: time budget for walking one window.
    public static let walkTimeBudget = Duration.milliseconds(1_500)
    /// Tunable: how long one accessibility call may wait for an app before giving up.
    public static let messagingTimeoutSeconds: Float = 1
    /// Business rule (spec §10): with fewer labelled controls than this, questions use a
    /// screenshot.
    public static let minimumLabelledElementsForTextOnly = 5
    /// Business rule (spec §10): with less screen text than this, questions use a screenshot.
    public static let minimumReadableCharactersForTextOnly = 200
}
