import Foundation
import Synchronization
import Testing

@testable import GlimCore

/// Records every switch Glim flips, and answers reads from what was set.
final class FakeSwitchboard: AccessibilitySwitchboard {
    struct Change: Equatable {
        let attribute: String
        let value: Bool
        let processIdentifier: pid_t
    }

    private let values = Mutex<[String: Bool]>([:])
    private let recordedChanges = Mutex<[Change]>([])
    private let recordedRoleReads = Mutex<[pid_t]>([])

    var changes: [Change] { recordedChanges.withLock { $0 } }
    var roleReads: [pid_t] { recordedRoleReads.withLock { $0 } }

    private static func key(_ attribute: String, _ processIdentifier: pid_t) -> String {
        "\(processIdentifier)/\(attribute)"
    }

    /// Sets a value as if another app (VoiceOver, a window manager) had set it.
    func preset(_ value: Bool, attribute: String, processIdentifier: pid_t) {
        values.withLock { $0[Self.key(attribute, processIdentifier)] = value }
    }

    func boolValue(of attribute: String, processIdentifier: pid_t) -> Bool? {
        values.withLock { $0[Self.key(attribute, processIdentifier)] }
    }

    func setBool(_ value: Bool, attribute: String, processIdentifier: pid_t) {
        preset(value, attribute: attribute, processIdentifier: processIdentifier)
        recordedChanges.withLock {
            $0.append(
                Change(attribute: attribute, value: value, processIdentifier: processIdentifier))
        }
    }

    func readRole(processIdentifier: pid_t) {
        recordedRoleReads.withLock { $0.append(processIdentifier) }
    }
}

struct AccessibilityWakeUpTests {
    static let enhanced = AccessibilityWakeUp.enhancedUserInterfaceAttribute
    static let manual = AccessibilityWakeUp.manualAccessibilityAttribute

    static func app(_ kind: ChromiumKind?, processIdentifier: pid_t = 42) -> ResolvedApp {
        ResolvedApp(
            identity: AppIdentity(
                bundleIdentifier: "dev.example.app", displayName: "Example", hasValidSignature: true
            ),
            bundleURL: URL(filePath: "/Applications/Example.app"),
            processIdentifier: processIdentifier)
    }

    func makeWakeUp(kind: ChromiumKind?) -> (AccessibilityWakeUp, FakeSwitchboard) {
        let switchboard = FakeSwitchboard()
        let wakeUp = AccessibilityWakeUp(switchboard: switchboard, kindOf: { _ in kind })
        return (wakeUp, switchboard)
    }

    @Test func nativeAppIsNeverSwitched() {
        let (wakeUp, switchboard) = makeWakeUp(kind: nil)

        #expect(wakeUp.wake(Self.app(nil), at: .now) == nil)
        #expect(switchboard.changes.isEmpty)
        #expect(switchboard.roleReads.isEmpty)
    }

    @Test func spotifyGetsTheEnhancedInterfaceSwitchAndAWait() {
        let (wakeUp, switchboard) = makeWakeUp(kind: .chromiumEmbedded)
        let now = ContinuousClock.now

        let deadline = wakeUp.wake(Self.app(.chromiumEmbedded), at: now)

        #expect(
            switchboard.changes == [
                .init(attribute: Self.enhanced, value: true, processIdentifier: 42)
            ])
        #expect(deadline == now + ScreenReadingLimits.chromiumTreeWait)
    }

    @Test func electronGetsTheManualSwitchOnlyOnce() {
        let (wakeUp, switchboard) = makeWakeUp(kind: .electron)

        #expect(wakeUp.wake(Self.app(.electron), at: .now) != nil)
        // Older Electron reports the switch as unsupported even though it took effect.
        switchboard.preset(false, attribute: Self.manual, processIdentifier: 42)
        #expect(wakeUp.wake(Self.app(.electron), at: .now) == nil)

        #expect(
            switchboard.changes == [
                .init(attribute: Self.manual, value: true, processIdentifier: 42)
            ])
    }

    @Test func chromeIsWokenByReadingItsRole() {
        let (wakeUp, switchboard) = makeWakeUp(kind: .chromeBrowser)

        #expect(wakeUp.wake(Self.app(.chromeBrowser), at: .now) != nil)
        #expect(wakeUp.wake(Self.app(.chromeBrowser), at: .now) == nil)

        #expect(switchboard.roleReads == [42, 42])
        #expect(switchboard.changes.isEmpty)
    }

    @Test func switchAlreadyOnIsLeftAlone() {
        let (wakeUp, switchboard) = makeWakeUp(kind: .chromiumEmbedded)
        switchboard.preset(true, attribute: Self.enhanced, processIdentifier: 42)

        #expect(wakeUp.wake(Self.app(.chromiumEmbedded), at: .now) == nil)
        #expect(switchboard.changes.isEmpty)
    }

    /// Window managers turn the switch off to move windows; Glim turns it back on and waits.
    @Test func switchTurnedOffByAnotherAppIsSetAgain() {
        let (wakeUp, switchboard) = makeWakeUp(kind: .chromiumEmbedded)
        _ = wakeUp.wake(Self.app(.chromiumEmbedded), at: .now)
        switchboard.preset(false, attribute: Self.enhanced, processIdentifier: 42)

        #expect(wakeUp.wake(Self.app(.chromiumEmbedded), at: .now) != nil)
        #expect(switchboard.changes.count == 2)
    }

    @Test func releaseTurnsOffOnlyWhatGlimTurnedOn() {
        let (wakeUp, switchboard) = makeWakeUp(kind: .chromiumEmbedded)
        switchboard.preset(true, attribute: Self.enhanced, processIdentifier: 7)
        _ = wakeUp.wake(Self.app(.chromiumEmbedded, processIdentifier: 7), at: .now)
        _ = wakeUp.wake(Self.app(.chromiumEmbedded, processIdentifier: 42), at: .now)

        wakeUp.releaseAll()

        #expect(switchboard.boolValue(of: Self.enhanced, processIdentifier: 42) == false)
        #expect(switchboard.boolValue(of: Self.enhanced, processIdentifier: 7) == true)
    }

    @Test func windowMoveTurnsTheSwitchOffAndBackOn() {
        let (wakeUp, switchboard) = makeWakeUp(kind: .chromiumEmbedded)
        switchboard.preset(true, attribute: Self.enhanced, processIdentifier: 42)
        var valueDuringMove: Bool?

        wakeUp.whileEnhancedInterfacePaused(processIdentifier: 42) {
            valueDuringMove = switchboard.boolValue(of: Self.enhanced, processIdentifier: 42)
        }

        #expect(valueDuringMove == false)
        #expect(switchboard.boolValue(of: Self.enhanced, processIdentifier: 42) == true)
    }

    @Test func windowMoveLeavesTheSwitchAloneWhenItIsOff() {
        let (wakeUp, switchboard) = makeWakeUp(kind: nil)

        wakeUp.whileEnhancedInterfacePaused(processIdentifier: 42) {}

        #expect(switchboard.changes.isEmpty)
    }
}
