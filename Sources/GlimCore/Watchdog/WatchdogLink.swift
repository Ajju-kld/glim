import Darwin
import Dispatch
import Foundation
import notify

/// Darwin notifications between Glim and the watchdog process.
///
/// They carry no data, so a spoofed "stop" can only stop Glim — never make it act.
public struct WatchdogLink: Sendable {
    /// Identifies an observation for ``cancel(_:)``.
    public struct Observation: Sendable {
        fileprivate let token: Int32
    }

    /// Why an observation could not be registered.
    public enum LinkError: Error, Sendable, Equatable {
        case registrationFailed(signal: String, status: UInt32)
    }

    /// Business rule: the prefix both processes use.
    public static let standardNamePrefix = "dev.straxs.Glim"

    private let namePrefix: String

    /// Creates a link; tests pass a unique prefix.
    public init(namePrefix: String = standardNamePrefix) {
        self.namePrefix = namePrefix
    }

    /// The full notification name for `signal`.
    public func notificationName(for signal: WatchdogSignal) -> String {
        "\(namePrefix).\(signal.rawValue)"
    }

    /// Posts `signal` to every process observing it.
    public func post(_ signal: WatchdogSignal) {
        notify_post(notificationName(for: signal))
    }

    /// Calls `handler` on a background queue each time `signal` is posted.
    public func observe(
        _ signal: WatchdogSignal, handler: @escaping @Sendable () -> Void
    ) throws(LinkError) -> Observation {
        var token: Int32 = 0
        let status = notify_register_dispatch(
            notificationName(for: signal), &token, DispatchQueue.global(qos: .userInteractive)
        ) { _ in
            handler()
        }
        guard status == NOTIFY_STATUS_OK else {
            throw .registrationFailed(signal: signal.rawValue, status: status)
        }
        return Observation(token: token)
    }

    /// Stops an observation.
    public func cancel(_ observation: Observation) {
        notify_cancel(observation.token)
    }

    /// Whether a process with `processIdentifier` exists (signal 0 checks without sending).
    public static func isProcessAlive(_ processIdentifier: pid_t) -> Bool {
        processIdentifier > 0 && kill(processIdentifier, 0) == 0
    }
}
