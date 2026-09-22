/// The watchdog's side of ⌃⌥⌘K: ask Glim to stop, and force it to stop if it doesn't answer.
public struct StopEscalator: Sendable {
    /// How the stop ended.
    public enum Result: Sendable, Equatable {
        /// Glim stopped itself and said so.
        case acknowledged
        /// Glim didn't answer in time and was force-quit.
        case forceStopped
    }

    /// Business rule (B-Q6): Glim has half a second to acknowledge before it is force-quit.
    public static let standardAcknowledgementTimeout = Duration.milliseconds(500)

    private let acknowledgementTimeout: Duration

    /// Creates an escalator.
    public init(acknowledgementTimeout: Duration = standardAcknowledgementTimeout) {
        self.acknowledgementTimeout = acknowledgementTimeout
    }

    /// Requests a stop, waits for the acknowledgement, and force-stops on silence.
    ///
    /// - Parameters:
    ///   - requestStop: Posts the stop request.
    ///   - waitForAcknowledgement: Waits up to the given time; true if Glim acknowledged.
    ///   - forceStop: Force-quits Glim.
    /// - Returns: Whether Glim stopped itself or had to be forced.
    public func stop(
        requestStop: @Sendable () -> Void,
        waitForAcknowledgement: @Sendable (Duration) async -> Bool,
        forceStop: @Sendable () -> Void
    ) async -> Result {
        requestStop()
        guard await waitForAcknowledgement(acknowledgementTimeout) else {
            forceStop()
            return .forceStopped
        }
        return .acknowledged
    }
}
