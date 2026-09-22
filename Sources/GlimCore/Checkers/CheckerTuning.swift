import Foundation

/// Tunable values for the second-opinion checkers.
public enum CheckerTuning {
    /// Tunable (B-Q23): a checker's disagreement counts only when it gives its own pick at least
    /// this probability; below it the checker abstains. Placeholder until calibrated on Testbed.
    public static let disagreementConfidenceThreshold = 0.60
    /// Business rule: checkers see at most this many candidates (Laya is weak past ~20 options).
    public static let shortlistLimit = 20
    /// Tunable: checkers must answer quickly or count as offline.
    public static let requestTimeoutSeconds: TimeInterval = 10
}
