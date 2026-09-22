import Foundation
import Testing

@testable import GlimCore

/// Execution-time re-checks: what Return would activate, and the screen changing while a
/// confirmation panel waits.
struct TaskRunnerRecheckTests {
    typealias Base = TaskRunnerTests

    func makeRunner(
        in directory: URL, model: FakeLanguageModel, screenReader: ScriptedScreenReader,
        decisions: ScriptedDecisions, executor: RecordingExecutor
    ) -> (TaskRunnerTests.Harness, TaskRunner) {
        let harness = TaskRunnerTests.Harness(
            model: model, screenReader: screenReader, executor: executor, decisions: decisions,
            auditLog: AuditLog(directory: directory))
        return (harness, harness.makeRunner())
    }

    @Test func returnThatWouldActivateAForbiddenButtonIsBlocked() async throws {
        try await withTemporaryDirectory { directory in
            let executor = RecordingExecutor()
            let (harness, runner) = makeRunner(
                in: directory,
                model: FakeLanguageModel(
                    answer:
                        #"{"kind":"task","steps":[{"action":"pressKey","app":"Testbed","key":"returnKey"}]}"#
                ),
                screenReader: ScriptedScreenReader(
                    table: Base.testbedTable, returnTargetTexts: ["Delete All"]),
                decisions: ScriptedDecisions(confirmAnswers: [true]), executor: executor)

            let outcome = await harness.run("press return", runner: runner)

            #expect(
                outcome
                    == .blocked(
                        .forbiddenAction(matchedPhrase: "delete", elementLabel: "Delete All"),
                        stepNumber: 1))
            #expect(executor.performed.isEmpty)
        }
    }

    @Test func returnConfirmationShowsWhatItActivates() async throws {
        try await withTemporaryDirectory { directory in
            let executor = RecordingExecutor()
            let decisions = ScriptedDecisions(confirmAnswers: [true])
            let (harness, runner) = makeRunner(
                in: directory,
                model: FakeLanguageModel(
                    answer:
                        #"{"kind":"task","steps":[{"action":"pressKey","app":"Testbed","key":"returnKey"}]}"#
                ),
                screenReader: ScriptedScreenReader(
                    table: Base.testbedTable, returnTargetTexts: ["OK"]),
                decisions: decisions, executor: executor)

            #expect(await harness.run("press return", runner: runner) == .completed)
            #expect(decisions.confirmationsShown.first?.elementLabel == "OK")
            #expect(decisions.confirmationsShown.first?.reasons == [.pressReturn(activates: "OK")])
        }
    }

    @Test func controlChangingWhileThePersonDecidesStopsTheTask() async throws {
        try await withTemporaryDirectory { directory in
            let screenReader = ScriptedScreenReader(table: Base.testbedTable)
            let changedSendButton = UIElementSnapshot.fixture(number: 4, label: "Delete")
            let changedTable = ElementTable(
                elements: [
                    Base.newItemButton, Base.deleteButton, Base.notesField, changedSendButton,
                    Base.archiveButton,
                ],
                handleIndexByElementNumber: Base.testbedTable.handleIndexByElementNumber,
                readableText: Base.testbedTable.readableText, wasTruncated: false)
            let executor = RecordingExecutor()
            let (harness, runner) = makeRunner(
                in: directory,
                model: FakeLanguageModel(answers: [
                    .success(
                        #"{"kind":"task","steps":[{"action":"click","app":"Testbed","target":"Send"}]}"#
                    ),
                    .success(#"{"elementNumber":4,"blocked":false}"#),
                ]),
                screenReader: screenReader,
                decisions: ScriptedDecisions(confirmAnswers: [true]) {
                    screenReader.replaceTable(with: changedTable)
                },
                executor: executor)

            let outcome = await harness.run("click send", runner: runner)

            #expect(outcome == .blocked(.changedWhileWaiting(description: "Send"), stepNumber: 1))
            #expect(executor.performed.isEmpty)
        }
    }
}

struct TaskRunnerLivePolicyTests {
    typealias Base = TaskRunnerTests

    @Test func tighteningDuringATaskAppliesToTheNextStep() async throws {
        try await withTemporaryDirectory { directory in
            let policy = ChangingPolicy(Base.testPolicy)
            let executor = RecordingExecutor {
                policy.update {
                    $0.appTrust.tiersByBundleIdentifier["dev.straxs.Glim.Testbed"] = .neverTouch
                }
            }
            let harness = TaskRunnerTests.Harness(
                model: FakeLanguageModel(answers: [
                    .success(
                        #"{"kind":"task","steps":[{"action":"click","app":"Testbed","target":"New Item"},{"action":"click","app":"Testbed","target":"New Item"}]}"#
                    ),
                    .success(#"{"elementNumber":1,"blocked":false}"#),
                    .success(#"{"elementNumber":1,"blocked":false}"#),
                ]),
                screenReader: ScriptedScreenReader(table: Base.testbedTable), executor: executor,
                decisions: ScriptedDecisions(), auditLog: AuditLog(directory: directory))

            let outcome = await harness.run(
                "click twice", runner: harness.makeRunner(policy: policy))

            #expect(
                outcome
                    == .blocked(
                        .blockedByTier(appName: "Testbed", tier: .neverTouch, action: .click),
                        stepNumber: 2))
            #expect(executor.performed.count == 1)
        }
    }

    @Test func looseningDuringATaskDoesNotReachIt() async throws {
        try await withTemporaryDirectory { directory in
            var strictPolicy = Base.testPolicy
            strictPolicy.riskWords.forbidden.append("archive")
            let policy = ChangingPolicy(strictPolicy)
            let harness = TaskRunnerTests.Harness(
                model: FakeLanguageModel(answers: [
                    .success(
                        #"{"kind":"task","steps":[{"action":"pressKey","app":"Testbed","key":"tab"},{"action":"click","app":"Testbed","target":"Item"}]}"#
                    ),
                    .success(#"{"elementNumber":5,"blocked":false}"#),
                ]),
                screenReader: ScriptedScreenReader(table: Base.testbedTable),
                executor: RecordingExecutor {
                    policy.update { $0.riskWords.forbidden.removeAll { $0 == "archive" } }
                },
                decisions: ScriptedDecisions(), auditLog: AuditLog(directory: directory))

            let outcome = await harness.run(
                "tab then click", runner: harness.makeRunner(policy: policy))

            #expect(
                outcome
                    == .blocked(
                        .forbiddenAction(matchedPhrase: "archive", elementLabel: "Archive"),
                        stepNumber: 2))
        }
    }
}

struct TaskRunnerExecutionTargetTests {
    typealias Base = TaskRunnerTests

    @Test func confirmedStepActsOnTheFreshlyReadControl() async throws {
        try await withTemporaryDirectory { directory in
            let screenReader = ScriptedScreenReader(table: Base.testbedTable)
            let sendWithNewValue = UIElementSnapshot(
                number: 4, role: "AXButton", label: "Send", value: "ready")
            let refreshedTable = ElementTable(
                elements: [
                    Base.newItemButton, Base.deleteButton, Base.notesField, sendWithNewValue,
                    Base.archiveButton,
                ],
                handleIndexByElementNumber: Base.testbedTable.handleIndexByElementNumber,
                readableText: Base.testbedTable.readableText, wasTruncated: false)
            let executor = RecordingExecutor()
            let harness = TaskRunnerTests.Harness(
                model: FakeLanguageModel(answers: [
                    .success(
                        #"{"kind":"task","steps":[{"action":"click","app":"Testbed","target":"Send"}]}"#
                    ),
                    .success(#"{"elementNumber":4,"blocked":false}"#),
                ]),
                screenReader: screenReader, executor: executor,
                decisions: ScriptedDecisions(confirmAnswers: [true]) {
                    screenReader.replaceTable(with: refreshedTable)
                },
                auditLog: AuditLog(directory: directory))

            #expect(await harness.run("click send") == .completed)
            #expect(executor.performed.first?.targetElement == sendWithNewValue)
        }
    }
}
