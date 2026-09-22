import Foundation
import Testing

@testable import GlimCore

/// A model that trips the kill switch mid-request and then fails, like a cancelled URLSession.
struct KillSwitchTrippingModel: LanguageModel {
    let killSwitch: KillSwitch

    func respond(to request: LanguageModelRequest) async throws(LanguageModelError) -> String {
        killSwitch.trip(.killHotkey)
        throw .serverUnreachable(reason: "cancelled")
    }
}

struct TaskRunnerLifecycleTests {
    typealias Base = TaskRunnerTests

    @Test func killSwitchDuringAModelCallReportsStoppedNotAServerError() async throws {
        try await withTemporaryDirectory { directory in
            let killSwitch = KillSwitch()
            let harness = TaskRunnerTests.Harness(
                killSwitch: killSwitch, model: FakeLanguageModel(answers: []),
                screenReader: ScriptedScreenReader(table: Base.testbedTable),
                executor: RecordingExecutor(),
                decisions: ScriptedDecisions(), auditLog: AuditLog(directory: directory))
            let runner = TaskRunner(
                dependencies: TaskRunnerDependencies(
                    planner: Planner(
                        languageModel: KillSwitchTrippingModel(killSwitch: killSwitch)),
                    screenReader: harness.screenReader, screenshotter: harness.screenshotter,
                    appResolver: AppResolver(
                        catalog: FakeAppCatalog(installed: [], running: []),
                        verifier: FakeSignatureVerifier(trustedBundleIdentifiers: [])),
                    checkerConsensus: CheckerConsensus(checkers: []), executor: harness.executor,
                    decisions: harness.decisions, narrator: harness.narrator,
                    killSwitch: killSwitch,
                    auditLog: harness.auditLog, takeoverMonitor: nil,
                    safetyPolicyProvider: { Base.testPolicy }, isWatchdogAlive: { true }),
                timing: Base.quickTiming)

            #expect(await harness.run("open notes", runner: runner) == .stopped(.killHotkey))
        }
    }

    @Test func taskDeadlineStopsTheTask() async throws {
        try await withTemporaryDirectory { directory in
            var shortDeadline = Base.testPolicy
            shortDeadline.limits.taskTimeoutSeconds = 0.000_001
            let harness = TaskRunnerTests.Harness(
                model: FakeLanguageModel(answers: [
                    .success(Base.clickNewItemPlan),
                    .success(#"{"elementNumber":1,"blocked":false}"#),
                ]),
                screenReader: ScriptedScreenReader(table: Base.testbedTable),
                executor: RecordingExecutor(),
                decisions: ScriptedDecisions(), auditLog: AuditLog(directory: directory))

            let outcome = await harness.run(
                "click new item", runner: harness.makeRunner(policy: ChangingPolicy(shortDeadline)))

            #expect(
                outcome
                    == .blocked(
                        .limitReached(.taskTimedOut(limitSeconds: 0.000_001)), stepNumber: 1))
        }
    }

    @Test func personTouchingTheMouseStopsTheNextStep() async throws {
        try await withTemporaryDirectory { directory in
            let killSwitch = KillSwitch()
            let inputClock = ScriptedInputClock()
            let monitor = TakeoverMonitor(
                killSwitch: killSwitch, inputClock: inputClock,
                timing: TakeoverMonitor.Timing(
                    settleDelay: .zero, pollInterval: .milliseconds(5), graceSeconds: 0.001))
            let executor = RecordingExecutor {
                inputClock.simulateHumanInput()
                await waitUntilTripped(killSwitch)
            }
            let harness = TaskRunnerTests.Harness(
                killSwitch: killSwitch,
                model: FakeLanguageModel(answers: [
                    .success(
                        #"{"kind":"task","steps":[{"action":"moveWindow","app":"Testbed","preset":"leftHalf"},{"action":"moveWindow","app":"Testbed","preset":"rightHalf"}]}"#
                    )
                ]),
                screenReader: ScriptedScreenReader(table: Base.testbedTable), executor: executor,
                decisions: ScriptedDecisions(), auditLog: AuditLog(directory: directory))
            let outcome = await harness.run(
                "left then right", runner: harness.makeRunner(takeoverMonitor: monitor))

            #expect(outcome == .stopped(.humanTookOver))
            #expect(executor.performed.count == 1)
        }
    }

    @Test func switchingThatDoesNotBringTheAppForwardCountsAsNoChange() async throws {
        try await withTemporaryDirectory { directory in
            let switchStep = #"{"action":"switchApp","app":"Messages"}"#
            let harness = TaskRunnerTests.Harness(
                model: FakeLanguageModel(answers: [
                    .success(
                        #"{"kind":"task","steps":[\#(switchStep),\#(switchStep),\#(switchStep),\#(switchStep)]}"#
                    )
                ]),
                screenReader: ScriptedScreenReader(table: Base.testbedTable),
                executor: RecordingExecutor(),
                decisions: ScriptedDecisions(), auditLog: AuditLog(directory: directory))

            let outcome = await harness.run("switch to messages")

            #expect(outcome == .blocked(.limitReached(.noVisibleChange(limit: 3)), stepNumber: 4))
        }
    }
}

/// Waits (at most two seconds) for the takeover monitor to notice, so the test doesn't depend
/// on scheduling luck.
func waitUntilTripped(_ killSwitch: KillSwitch) async {
    let pollInterval = Duration.milliseconds(5)
    let maximumPolls = 400
    for _ in 0..<maximumPolls where killSwitch.isArmed {
        do {
            try await Task.sleep(for: pollInterval)
        } catch {
            return
        }
    }
}
