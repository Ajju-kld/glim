import Synchronization

/// The shared stop signal for everything Glim does.
///
/// Tripping is immediate and sticky: the executor checks the switch right before every
/// operating-system call, and it stays tripped until the person clicks Re-arm.
public final class KillSwitch: Sendable {
    private struct State {
        var tripReason: TripReason?
        var handlers: [Int: @Sendable (TripReason) -> Void] = [:]
        var nextHandlerIdentifier = 0
    }

    private let state = Mutex(State())

    /// Creates an armed kill switch.
    public init() {}

    /// Whether actions may run.
    public var isArmed: Bool {
        state.withLock { $0.tripReason == nil }
    }

    /// Why the switch was tripped, or nil while armed.
    public var tripReason: TripReason? {
        state.withLock { $0.tripReason }
    }

    /// Trips the switch and notifies every handler once.
    ///
    /// - Parameter reason: What stopped Glim, shown in the guard popup.
    /// - Returns: `true` if this call tripped the switch; `false` if it was already tripped.
    @discardableResult
    public func trip(_ reason: TripReason) -> Bool {
        let handlersToNotify: [@Sendable (TripReason) -> Void]? = state.withLock { current in
            guard current.tripReason == nil else {
                return nil
            }
            current.tripReason = reason
            return Array(current.handlers.values)
        }
        guard let handlersToNotify else {
            return false
        }
        // Handlers run outside the lock so they can read the switch without deadlocking.
        for handler in handlersToNotify {
            handler(reason)
        }
        return true
    }

    /// Re-arms the switch after the person clicks Re-arm.
    public func rearm() {
        state.withLock { $0.tripReason = nil }
    }

    /// Registers a handler that runs when the switch trips, such as cancelling the task.
    ///
    /// - Parameter handler: Called once, with the trip reason, outside the switch's lock.
    /// - Returns: A token for ``removeTripHandler(_:)``.
    public func addTripHandler(
        _ handler: @escaping @Sendable (TripReason) -> Void
    ) -> TripHandlerToken {
        state.withLock { current in
            let handlerIdentifier = current.nextHandlerIdentifier
            current.nextHandlerIdentifier += 1
            current.handlers[handlerIdentifier] = handler
            return TripHandlerToken(handlerIdentifier: handlerIdentifier)
        }
    }

    /// Removes a handler registered with ``addTripHandler(_:)``.
    public func removeTripHandler(_ token: TripHandlerToken) {
        state.withLock { current in
            current.handlers[token.handlerIdentifier] = nil
        }
    }

    /// Throws if the switch is tripped. The executor calls this immediately before every
    /// operating-system call, so no queued action can slip through after a trip.
    public func ensureArmed() throws(GuardViolation) {
        guard isArmed else {
            throw .killSwitchTripped
        }
    }
}

/// Identifies a registered trip handler so it can be removed.
public struct TripHandlerToken: Sendable, Hashable {
    fileprivate let handlerIdentifier: Int
}
