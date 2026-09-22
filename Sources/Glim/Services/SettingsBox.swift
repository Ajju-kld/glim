import GlimCore
import Synchronization

/// The current settings, readable from any thread, so a running task sees a tightening at once.
final class SettingsBox: Sendable {
    private let storedSettings = Mutex(GlimSettings.safeDefaults)

    var settings: GlimSettings {
        storedSettings.withLock { $0 }
    }

    func update(_ newSettings: GlimSettings) {
        storedSettings.withLock { $0 = newSettings }
    }
}
