import CoreGraphics
import Foundation

/// Reports how long ago a person last used the keyboard, mouse or trackpad.
public protocol HumanInputClock: Sendable {
    /// Seconds since the last real human input.
    func secondsSinceLastHumanInput() -> TimeInterval
}

/// The live clock, read from the hardware input state.
///
/// Glim posts its own events straight to the target process, so they never reach this state:
/// only a real person's input resets it. No extra permission is needed.
public struct HardwareInputClock: HumanInputClock {
    private static let watchedEventTypes: [CGEventType] = [
        .keyDown, .flagsChanged, .leftMouseDown, .rightMouseDown, .otherMouseDown, .mouseMoved,
        .leftMouseDragged, .rightMouseDragged, .scrollWheel,
    ]

    /// Creates the live clock.
    public init() {}

    /// The most recent of all watched input types.
    public func secondsSinceLastHumanInput() -> TimeInterval {
        Self.watchedEventTypes
            .map { CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: $0) }
            .min() ?? .infinity
    }
}
