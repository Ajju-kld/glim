import Foundation
import Synchronization

/// Reads and sets the app-wide switches that make Chromium apps build their accessibility tree.
public protocol AccessibilitySwitchboard: Sendable {
    /// The switch's current value, or nil when the app doesn't report it.
    func boolValue(of attribute: String, processIdentifier: pid_t) -> Bool?
    /// Sets the switch. Some apps report failure even when the switch took effect, so the result
    /// isn't trusted.
    func setBool(_ value: Bool, attribute: String, processIdentifier: pid_t)
    /// Reads the app's role, which wakes Chrome-family browsers.
    func readRole(processIdentifier: pid_t)
}

/// Makes Chromium apps show their controls before Glim reads them, and undoes it on quit.
///
/// Native apps are never touched. A switch that was already on (VoiceOver sets one) is left on,
/// and only switches Glim turned on are turned off again.
public final class AccessibilityWakeUp: Sendable {
    /// The signal Electron listens for.
    public static let manualAccessibilityAttribute = "AXManualAccessibility"
    /// The signal apps embedding Chromium (Spotify) and VoiceOver use.
    public static let enhancedUserInterfaceAttribute = "AXEnhancedUserInterface"

    private struct SwitchedApp {
        let attribute: String
    }

    private let switchboard: any AccessibilitySwitchboard
    private let kindOf: @Sendable (ResolvedApp) -> ChromiumKind?
    /// Apps Glim turned a switch on in, by process.
    private let switchedApps = Mutex<[pid_t: SwitchedApp]>([:])
    /// Chrome-family browsers already woken, by process.
    private let wokenBrowsers = Mutex<Set<pid_t>>([])

    /// Creates the wake-up, detecting Chromium apps from their bundles unless told otherwise.
    public init(
        switchboard: any AccessibilitySwitchboard,
        kindOf: @escaping @Sendable (ResolvedApp) -> ChromiumKind? = { app in
            ChromiumKind.detect(
                bundleURL: app.bundleURL, bundleIdentifier: app.identity.bundleIdentifier)
        }
    ) {
        self.switchboard = switchboard
        self.kindOf = kindOf
    }

    /// Wakes `app` if it is built on Chromium. Returns how long a read that finds no controls
    /// should keep trying, when the app was only just woken; nil when there's nothing to wait for.
    public func wake(_ app: ResolvedApp, at instant: ContinuousClock.Instant)
        -> ContinuousClock.Instant?
    {
        guard let processIdentifier = app.processIdentifier, let kind = kindOf(app) else {
            return nil
        }
        let waitDeadline = instant + ScreenReadingLimits.chromiumTreeWait
        switch kind {
        case .chromeBrowser:
            switchboard.readRole(processIdentifier: processIdentifier)
            let isFirstWake = wokenBrowsers.withLock { $0.insert(processIdentifier).inserted }
            return isFirstWake ? waitDeadline : nil
        case .electron:
            // Older Electron reads the switch back as unsupported even after it took effect, so
            // it is set once per process rather than whenever it reads as off.
            let alreadySwitched = switchedApps.withLock { $0[processIdentifier] != nil }
            guard !alreadySwitched else {
                return nil
            }
            return turnOn(Self.manualAccessibilityAttribute, in: processIdentifier)
                ? waitDeadline : nil
        case .chromiumEmbedded:
            // Window managers turn this switch off to move windows, so it is checked every time.
            return turnOn(Self.enhancedUserInterfaceAttribute, in: processIdentifier)
                ? waitDeadline : nil
        }
    }

    /// Turns every switch Glim turned on back off. Called when Glim quits.
    public func releaseAll() {
        let released = switchedApps.withLock { apps in
            defer { apps.removeAll() }
            return apps
        }
        for (processIdentifier, switchedApp) in released {
            switchboard.setBool(
                false, attribute: switchedApp.attribute, processIdentifier: processIdentifier)
        }
    }

    /// Runs `moveWindow` with the enhanced-interface switch off, then turns it back on. With the
    /// switch on, apps animate window moves and land on the wrong frame.
    public func whileEnhancedInterfacePaused<Result, Failure: Error>(
        processIdentifier: pid_t, _ moveWindow: () throws(Failure) -> Result
    ) throws(Failure) -> Result {
        let attribute = Self.enhancedUserInterfaceAttribute
        guard switchboard.boolValue(of: attribute, processIdentifier: processIdentifier) == true
        else {
            return try moveWindow()
        }
        switchboard.setBool(false, attribute: attribute, processIdentifier: processIdentifier)
        defer {
            switchboard.setBool(true, attribute: attribute, processIdentifier: processIdentifier)
        }
        return try moveWindow()
    }

    /// Turns `attribute` on unless it already is. Returns whether it was turned on now.
    private func turnOn(_ attribute: String, in processIdentifier: pid_t) -> Bool {
        guard switchboard.boolValue(of: attribute, processIdentifier: processIdentifier) != true
        else {
            return false
        }
        switchboard.setBool(true, attribute: attribute, processIdentifier: processIdentifier)
        switchedApps.withLock { $0[processIdentifier] = SwitchedApp(attribute: attribute) }
        return true
    }
}
