import Foundation
import Testing

@testable import GlimCore

struct TaskRunnerTests {
    static let testbedURL = URL(filePath: "/Applications/Testbed.app")
    static let newItemButton = UIElementSnapshot.fixture(number: 1, label: "New Item")
    static let deleteButton = UIElementSnapshot.fixture(number: 2, label: "Delete")
    static let notesField = UIElementSnapshot.fixture(
        number: 3, role: "AXTextField", label: "Notes field")
    static let sendButton = UIElementSnapshot.fixture(number: 4, label: "Send")
    static let archiveButton = UIElementSnapshot.fixture(number: 5, label: "Archive")

    static let testbedTable = ElementTable(
        elements: [newItemButton, deleteButton, notesField, sendButton, archiveButton],
        handleIndexByElementNumber: [1: 1, 2: 2, 3: 3, 4: 4, 5: 5],
        readableText: String(repeating: "Testbed practice window text. ", count: 10),
        wasTruncated: false)

    static let quickTiming = RunnerTiming(
        settleAfterAction: .zero, appLaunchTimeout: .milliseconds(50),
        appLaunchPollInterval: .milliseconds(5), windowWaitTimeout: .seconds(1))

    /// Plans always go through the approval panel here, so each test can check it; the
    /// tests of asking only before danger turn `asksOnlyBeforeDangerousSteps` back on.
    static var testPolicy: SafetyPolicy {
        var policy = SafetyPolicy.safeDefaults
        policy.limits.minimumSecondsBetweenActions = 0
        policy.asksOnlyBeforeDangerousSteps = false
        return policy
    }

    static var dangerOnlyPolicy: SafetyPolicy {
        var policy = testPolicy
        policy.asksOnlyBeforeDangerousSteps = true
        return policy
    }

    struct Harness {
        var killSwitch = KillSwitch()
        let model: FakeLanguageModel
        let screenReader: ScriptedScreenReader
        let screenshotter = RecordingScreenshotter()
        let executor: RecordingExecutor
        let decisions: ScriptedDecisions
        let narrator = RecordingNarrator()
        let events = EventRecorder()
        let auditLog: AuditLog

        func makeRunner(
            frontmostBundleIdentifier: String = "dev.straxs.Glim.Testbed",
            checkers: [any TargetChecker] = [],
            isWatchdogAlive: Bool = true,
            policy: ChangingPolicy = ChangingPolicy(testPolicy),
            takeoverMonitor: TakeoverMonitor? = nil,
            timing: RunnerTiming = quickTiming
        ) -> TaskRunner {
            let runningApps = [
                RunningApp(
                    name: "Testbed", bundleIdentifier: "dev.straxs.Glim.Testbed",
                    processIdentifier: 300,
                    isFrontmost: frontmostBundleIdentifier == "dev.straxs.Glim.Testbed",
                    bundleURL: testbedURL),
                RunningApp(
                    name: "Messages", bundleIdentifier: "com.apple.MobileSMS",
                    processIdentifier: 400,
                    isFrontmost: false, bundleURL: nil),
                RunningApp(
                    name: "Passwords", bundleIdentifier: "com.apple.Passwords",
                    processIdentifier: 500,
                    isFrontmost: frontmostBundleIdentifier == "com.apple.Passwords", bundleURL: nil),
            ]
            let catalog = FakeAppCatalog(
                installed: [
                    InstalledApp(
                        name: "Testbed", fileName: "Testbed",
                        bundleIdentifier: "dev.straxs.Glim.Testbed", url: testbedURL)
                ],
                running: runningApps)
            let resolver = AppResolver(
                catalog: catalog,
                verifier: FakeSignatureVerifier(
                    trustedBundleIdentifiers: Set(runningApps.map(\.bundleIdentifier))))
            let dependencies = TaskRunnerDependencies(
                planner: Planner(languageModel: model),
                screenReader: screenReader,
                screenshotter: screenshotter,
                appResolver: resolver,
                checkerConsensus: CheckerConsensus(checkers: checkers),
                executor: executor,
                decisions: decisions,
                narrator: narrator,
                killSwitch: killSwitch,
                auditLog: auditLog,
                takeoverMonitor: takeoverMonitor,
                safetyPolicyProvider: { policy.current },
                isWatchdogAlive: { isWatchdogAlive })
            return TaskRunner(dependencies: dependencies, timing: timing)
        }

        func run(_ transcript: String, runner: TaskRunner? = nil) async -> TaskOutcome {
            await (runner ?? makeRunner()).run(transcript: transcript) { event in
                events.record(event)
            }
        }
    }

    func makeHarness(
        in directory: URL,
        modelAnswers: [String],
        approvesPlans: Bool = true,
        confirmAnswers: [Bool] = [],
        screenChanges: Bool = true,
        table: ElementTable = testbedTable,
        executor: RecordingExecutor? = nil
    ) -> Harness {
        Harness(
            model: FakeLanguageModel(answers: modelAnswers.map { .success($0) }),
            screenReader: ScriptedScreenReader(table: table, changesEveryRead: screenChanges),
            executor: executor ?? RecordingExecutor(),
            decisions: ScriptedDecisions(
                approvesPlans: approvesPlans, confirmAnswers: confirmAnswers),
            auditLog: AuditLog(directory: directory))
    }

    static let clickNewItemPlan =
        #"{"kind":"task","steps":[{"action":"click","app":"Testbed","target":"New Item"}]}"#
    /// A target that is no control's exact label, so the model has to pick one.
    static let clickNewItemLooselyPlan =
        #"{"kind":"task","steps":[{"action":"click","app":"Testbed","target":"the new item button"}]}"#

    // MARK: - Questions

    @Test func questionIsAnsweredFromScreenText() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(
                in: directory,
                modelAnswers: [
                    #"{"kind":"question","steps":[]}"#, #"{"answer":"It's the Testbed window."}"#,
                ])

            let outcome = await harness.run("what's on my screen")

            #expect(outcome == .answered("It's the Testbed window."))
            #expect(harness.narrator.lines == ["It's the Testbed window."])
            #expect(harness.executor.performed.isEmpty)
            #expect(harness.screenshotter.captures == 0)
        }
    }

    @Test func thinScreenAnswersFromAScreenshot() async throws {
        try await withTemporaryDirectory { directory in
            let thinTable = ElementTable(
                elements: [Self.newItemButton], handleIndexByElementNumber: [1: 1],
                readableText: "", wasTruncated: false)
            let harness = makeHarness(
                in: directory,
                modelAnswers: [#"{"kind":"question","steps":[]}"#, #"{"answer":"A photo."}"#],
                table: thinTable)

            _ = await harness.run("what is this")

            #expect(harness.screenshotter.captures == 1)
            #expect(harness.model.requests.last?.imagesPNG.isEmpty == false)
        }
    }

    @Test func neverTouchFrontAppIsNeverRead() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(
                in: directory, modelAnswers: [#"{"kind":"question","steps":[]}"#])

            let outcome = await harness.run(
                "read this",
                runner: harness.makeRunner(frontmostBundleIdentifier: "com.apple.Passwords"))

            guard case .answered = outcome else {
                Issue.record("Expected a spoken refusal, got \(outcome)")
                return
            }
            #expect(!harness.screenReader.appsRead.contains("Passwords"))
            #expect(harness.screenshotter.captures == 0)
            #expect(harness.model.requests.count == 1)
        }
    }

    // MARK: - Tasks

    @Test func approvedPlanRunsThroughTheGateAndFinishes() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(
                in: directory,
                modelAnswers: [
                    #"{"kind":"task","steps":[{"action":"click","app":"Testbed","target":"New Item"},{"action":"typeText","app":"Testbed","target":"Notes field","text":"buy milk"}]}"#,
                    #"{"elementNumber":1,"blocked":false}"#,
                    #"{"elementNumber":3,"blocked":false}"#,
                ])

            let outcome = await harness.run("click new item and write buy milk")

            #expect(outcome == .completed)
            #expect(harness.decisions.plansShown.count == 1)
            #expect(
                harness.executor.performed.map(\.targetElement) == [
                    Self.newItemButton, Self.notesField,
                ])
            #expect(
                harness.executor.performed.last?.step
                    == .typeText(appName: "Testbed", target: "Notes field", text: "buy milk"))
            #expect(harness.narrator.lines.last == "Done")
            #expect(harness.events.events.last == .finished(.completed))
        }
    }

    @Test func forbiddenPlanIsRejectedBeforeApproval() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(
                in: directory,
                modelAnswers: [
                    #"{"kind":"task","steps":[{"action":"click","app":"Testbed","target":"Delete"}]}"#
                ])

            let outcome = await harness.run("delete it")

            #expect(
                outcome
                    == .blocked(
                        .forbiddenAction(matchedPhrase: "delete", elementLabel: "Delete"),
                        stepNumber: 1))
            #expect(harness.decisions.plansShown.isEmpty)
            #expect(harness.executor.performed.isEmpty)
        }
    }

    @Test func cancelledPlanDoesNothing() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(
                in: directory, modelAnswers: [Self.clickNewItemPlan], approvesPlans: false)

            #expect(await harness.run("click new item") == .cancelled)
            #expect(harness.executor.performed.isEmpty)
        }
    }

    @Test func forbiddenPickAtRunTimeIsBlocked() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(
                in: directory,
                modelAnswers: [
                    Self.clickNewItemLooselyPlan, #"{"elementNumber":2,"blocked":false}"#,
                ])

            let outcome = await harness.run("click new item")

            #expect(
                outcome
                    == .blocked(
                        .forbiddenAction(matchedPhrase: "delete", elementLabel: "Delete"),
                        stepNumber: 1))
            #expect(harness.executor.performed.isEmpty)
        }
    }

    @Test func lowRiskPlanStartsWithoutThePanel() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(in: directory, modelAnswers: [Self.clickNewItemPlan])

            let outcome = await harness.run(
                "click new item",
                runner: harness.makeRunner(policy: ChangingPolicy(Self.dangerOnlyPolicy)))

            #expect(outcome == .completed)
            #expect(harness.decisions.plansShown.isEmpty)
            #expect(harness.executor.performed.count == 1)
            #expect(
                !harness.events.events.contains { event in
                    if case .awaitingPlanApproval = event { return true }
                    return false
                })
        }
    }

    @Test func dangerousStepAsksAtTheStepInsteadOfThroughAPlan() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(
                in: directory,
                modelAnswers: [
                    #"{"kind":"task","steps":[{"action":"click","app":"Testbed","target":"Send"}]}"#
                ],
                approvesPlans: false, confirmAnswers: [false])

            let outcome = await harness.run(
                "send it",
                runner: harness.makeRunner(policy: ChangingPolicy(Self.dangerOnlyPolicy)))

            #expect(outcome == .stopped(.panelCancelled))
            #expect(harness.decisions.plansShown.isEmpty)
            #expect(
                harness.decisions.confirmationsShown.first?.reasons == [
                    .riskyWord(matchedPhrase: "send", elementLabel: "Send")
                ])
            #expect(harness.executor.performed.isEmpty)
        }
    }

    /// Notes can be running with every window closed; reopening it brings a window back a
    /// moment later, and the step waits for it instead of failing.
    @Test func stepWaitsForAWindowThatAppearsLate() async throws {
        try await withTemporaryDirectory { directory in
            let harness = Harness(
                model: FakeLanguageModel(answers: [.success(Self.clickNewItemPlan)]),
                screenReader: ScriptedScreenReader(table: Self.testbedTable, readsWithoutWindow: 3),
                executor: RecordingExecutor(), decisions: ScriptedDecisions(),
                auditLog: AuditLog(directory: directory))

            #expect(await harness.run("click new item") == .completed)
            #expect(harness.executor.performed.map(\.targetElement) == [Self.newItemButton])
        }
    }

    @Test func windowThatNeverAppearsFailsWithTheReason() async throws {
        try await withTemporaryDirectory { directory in
            let harness = Harness(
                model: FakeLanguageModel(answers: [.success(Self.clickNewItemPlan)]),
                screenReader: ScriptedScreenReader(
                    table: Self.testbedTable, readsWithoutWindow: .max),
                executor: RecordingExecutor(), decisions: ScriptedDecisions(),
                auditLog: AuditLog(directory: directory))

            #expect(await harness.run("click new item") == .failed("Testbed has no open window."))
            #expect(harness.executor.performed.isEmpty)
        }
    }

    /// Asking only before danger must not mean clicking whatever the model picked: a pick that
    /// doesn't match the plan is sent back to the model, and never clicked.
    @Test func pickThatDoesNotMatchThePlanIsRetriedNotClicked() async throws {
        try await withTemporaryDirectory { directory in
            let archivePick = #"{"elementNumber":5,"blocked":false}"#
            let harness = makeHarness(
                in: directory,
                modelAnswers: [
                    #"{"kind":"task","steps":[{"action":"click","app":"Testbed","target":"Compose"}]}"#,
                    archivePick, archivePick, archivePick,
                ])

            let outcome = await harness.run(
                "compose", runner: harness.makeRunner(policy: ChangingPolicy(Self.dangerOnlyPolicy))
            )

            #expect(
                outcome == .blocked(.limitReached(.tooManyTriesForStep(limit: 3)), stepNumber: 1))
            #expect(harness.executor.performed.isEmpty)
            #expect(harness.decisions.confirmationsShown.isEmpty)
            #expect(
                harness.model.requests.last?.userPrompt.contains("doesn't match the plan") == true)
        }
    }

    /// Notes' note body has no name. When it is the only place on screen to type, typing
    /// goes there without asking the model.
    @Test func onlyFieldOnScreenTakesTheTextEvenWithoutAName() async throws {
        try await withTemporaryDirectory { directory in
            let untitledBody = UIElementSnapshot.fixture(
                number: 2, role: "AXTextArea",
                label: ElementTableBuilder.untitledLabel(for: "AXTextArea"))
            let table = ElementTable(
                elements: [Self.newItemButton, untitledBody],
                handleIndexByElementNumber: [1: 1, 2: 2],
                readableText: String(repeating: "text ", count: 60), wasTruncated: false)
            let harness = makeHarness(
                in: directory,
                modelAnswers: [
                    #"{"kind":"task","steps":[{"action":"typeText","app":"Testbed","target":"note body","text":"Apple"}]}"#
                ],
                table: table)

            let outcome = await harness.run(
                "write Apple",
                runner: harness.makeRunner(policy: ChangingPolicy(Self.dangerOnlyPolicy)))

            #expect(outcome == .completed)
            #expect(harness.executor.performed.map(\.targetElement) == [untitledBody])
            #expect(harness.model.requests.count == 1)
        }
    }

    /// The window read after one step is fresh, so the next step in the same app reuses it
    /// instead of walking the window again (a big window can take over a second to read).
    @Test func nextStepReusesTheWindowReadAfterThePreviousStep() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(
                in: directory,
                modelAnswers: [
                    #"{"kind":"task","steps":[{"action":"click","app":"Testbed","target":"New Item"},{"action":"click","app":"Testbed","target":"Archive"}]}"#
                ])

            #expect(await harness.run("click new item then archive") == .completed)
            // Planning, step 1 before and after, step 2 after: the read after step 1 serves step 2.
            #expect(harness.screenReader.appsRead.count == 4)
        }
    }

    @Test func exactlyLabelledTargetNeedsNoPickFromTheModel() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(in: directory, modelAnswers: [Self.clickNewItemPlan])

            #expect(await harness.run("click new item") == .completed)
            #expect(harness.model.requests.count == 1)
            #expect(harness.executor.performed.map(\.targetElement) == [Self.newItemButton])
        }
    }

    @Test func confirmedRiskyStepRuns() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(
                in: directory,
                modelAnswers: [
                    #"{"kind":"task","steps":[{"action":"click","app":"Testbed","target":"Send"}]}"#,
                    #"{"elementNumber":4,"blocked":false}"#,
                ],
                confirmAnswers: [true])

            #expect(await harness.run("send it") == .completed)
            #expect(
                harness.decisions.confirmationsShown.first?.reasons == [
                    .riskyWord(matchedPhrase: "send", elementLabel: "Send")
                ])
            #expect(harness.executor.performed.count == 1)
        }
    }

    @Test func refusedConfirmationStopsGlim() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(
                in: directory,
                modelAnswers: [
                    #"{"kind":"task","steps":[{"action":"click","app":"Testbed","target":"Send"}]}"#,
                    #"{"elementNumber":4,"blocked":false}"#,
                ],
                confirmAnswers: [false])

            #expect(await harness.run("send it") == .stopped(.panelCancelled))
            #expect(harness.killSwitch.tripReason == .panelCancelled)
            #expect(harness.executor.performed.isEmpty)
        }
    }

    @Test func killSwitchDuringTheTaskStopsTheNextStep() async throws {
        try await withTemporaryDirectory { directory in
            let killingHarness = makeHarness(
                in: directory,
                modelAnswers: [
                    #"{"kind":"task","steps":[{"action":"click","app":"Testbed","target":"New Item"},{"action":"click","app":"Testbed","target":"New Item"}]}"#,
                    #"{"elementNumber":1,"blocked":false}"#,
                    #"{"elementNumber":1,"blocked":false}"#,
                ])
            let sharedKillSwitch = KillSwitch()
            let executor = RecordingExecutor(killSwitchToTripOnFirstAction: sharedKillSwitch)
            let harness = Harness(
                killSwitch: sharedKillSwitch, model: killingHarness.model,
                screenReader: killingHarness.screenReader, executor: executor,
                decisions: killingHarness.decisions, auditLog: killingHarness.auditLog)

            #expect(await harness.run("click twice") == .stopped(.killHotkey))
            #expect(executor.performed.count == 1)
        }
    }

    @Test func repeatedBadPicksBlockTheStep() async throws {
        try await withTemporaryDirectory { directory in
            let badPick = #"{"elementNumber":42,"blocked":false}"#
            let harness = makeHarness(
                in: directory,
                modelAnswers: [Self.clickNewItemLooselyPlan, badPick, badPick, badPick])

            let outcome = await harness.run("click new item")

            #expect(
                outcome == .blocked(.limitReached(.tooManyTriesForStep(limit: 3)), stepNumber: 1))
            #expect(
                harness.model.requests.last?.userPrompt.contains(
                    "Your previous answer was rejected") == true)
        }
    }

    @Test func missingWatchdogBlocksActions() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(
                in: directory,
                modelAnswers: [Self.clickNewItemPlan, #"{"elementNumber":1,"blocked":false}"#])

            let outcome = await harness.run(
                "click new item", runner: harness.makeRunner(isWatchdogAlive: false))

            #expect(outcome == .blocked(.watchdogMissing, stepNumber: 1))
        }
    }

    @Test func checkerDisagreementIsShownForConfirmation() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(
                in: directory,
                modelAnswers: [Self.clickNewItemPlan, #"{"elementNumber":1,"blocked":false}"#],
                confirmAnswers: [true])
            let disagreeingChecker = ScriptedChecker(
                name: "Laya",
                verdict: .confidentlyDisagrees(alternative: Self.archiveButton, probability: 0.9))

            let outcome = await harness.run(
                "click new item", runner: harness.makeRunner(checkers: [disagreeingChecker]))

            #expect(outcome == .completed)
            #expect(
                harness.decisions.confirmationsShown.first?.reasons
                    == [.checkerDisagrees(checkerName: "Laya", checkerChoice: "Archive")])
        }
    }

    @Test func unreachableModelFailsWithTheFix() async throws {
        try await withTemporaryDirectory { directory in
            let harness = Harness(
                model: FakeLanguageModel(answers: [.failure(.serverUnreachable(reason: "refused"))]
                ),
                screenReader: ScriptedScreenReader(table: Self.testbedTable),
                executor: RecordingExecutor(), decisions: ScriptedDecisions(),
                auditLog: AuditLog(directory: directory))

            let outcome = await harness.run("click new item")

            #expect(
                outcome
                    == .failed(LanguageModelError.serverUnreachable(reason: "refused").explanation))
        }
    }

    @Test func spokenStopTripsTheKillSwitch() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(in: directory, modelAnswers: [])

            #expect(await harness.run("stop") == .stopped(.spokenStop))
            #expect(harness.killSwitch.tripReason == .spokenStop)
            #expect(harness.model.requests.isEmpty)
        }
    }

    @Test func actionsThatChangeNothingAreLimited() async throws {
        try await withTemporaryDirectory { directory in
            let tabStep = #"{"action":"pressKey","app":"Testbed","key":"tab"}"#
            let harness = makeHarness(
                in: directory,
                modelAnswers: [
                    #"{"kind":"task","steps":[\#(tabStep),\#(tabStep),\#(tabStep),\#(tabStep)]}"#
                ],
                screenChanges: false)

            let outcome = await harness.run("press tab four times")

            #expect(outcome == .blocked(.limitReached(.noVisibleChange(limit: 3)), stepNumber: 4))
            #expect(harness.executor.performed.count == 3)
        }
    }

    @Test func everyStageIsAudited() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(
                in: directory,
                modelAnswers: [Self.clickNewItemPlan, #"{"elementNumber":1,"blocked":false}"#])

            _ = await harness.run("click new item")

            let kinds = try await harness.auditLog.readAllEvents().map(\.kind)
            #expect(kinds.contains(.transcript))
            #expect(kinds.contains(.planApproved))
            #expect(kinds.contains(.gateDecision))
            #expect(kinds.contains(.actionPerformed))
            #expect(kinds.last == .taskFinished)
        }
    }
}
