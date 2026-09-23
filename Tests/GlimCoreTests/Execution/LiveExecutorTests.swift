import Foundation
import Testing

@testable import GlimCore

struct LiveExecutorTests {
    @Test func trippedKillSwitchStopsBeforeAnyAction() async {
        let killSwitch = KillSwitch()
        killSwitch.trip(.stopButton)
        let executor = LiveExecutor(accessibility: AccessibilityService(), killSwitch: killSwitch)
        let calculator = ResolvedApp(
            identity: AppIdentity(
                bundleIdentifier: "com.apple.calculator", displayName: "Calculator",
                hasValidSignature: true),
            bundleURL: URL(filePath: "/System/Applications/Calculator.app"), processIdentifier: nil)

        await #expect(throws: ExecutionError.stopped) {
            try await executor.perform(
                ExecutableAction(
                    step: .openApp(appName: "Calculator"), app: calculator, targetElement: nil))
        }
    }

    @Test func speakIsNotAnExecutorAction() async {
        let executor = LiveExecutor(accessibility: AccessibilityService(), killSwitch: KillSwitch())
        let notes = ResolvedApp(identity: .notes, bundleURL: nil, processIdentifier: nil)

        await #expect(throws: ExecutionError.self) {
            try await executor.perform(
                ExecutableAction(step: .speak(text: "hi"), app: notes, targetElement: nil))
        }
    }

    @Test func inAppActionNeedsARunningApp() async {
        let executor = LiveExecutor(accessibility: AccessibilityService(), killSwitch: KillSwitch())
        let notes = ResolvedApp(identity: .notes, bundleURL: nil, processIdentifier: nil)

        await #expect(throws: ExecutionError.appNotRunning(appName: "Notes")) {
            try await executor.perform(
                ExecutableAction(
                    step: .pressKey(appName: "Notes", key: .tab), app: notes, targetElement: nil))
        }
    }
}
