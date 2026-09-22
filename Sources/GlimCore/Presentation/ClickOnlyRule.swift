import AppKit

/// Approvals must be real mouse clicks (spec §5.5): never a key press, never keyboard
/// navigation, and never a click that was already on its way when the panel appeared.
public enum ClickOnlyRule {
    /// Tunable: how long a new panel's buttons ignore clicks, so a click in progress lands
    /// harmlessly.
    public static let armingDelay = Duration.milliseconds(800)

    /// Whether the event that triggered a button was a primary mouse click.
    public static func isMouseClick(_ eventType: NSEvent.EventType?) -> Bool {
        eventType == .leftMouseUp || eventType == .leftMouseDown
    }
}
