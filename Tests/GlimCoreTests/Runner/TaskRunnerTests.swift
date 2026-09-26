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

    /// A window that gave Glim no controls at all.
    static let emptyTable = ElementTable(
        elements: [], handleIndexByElementNumber: [:], readableText: "", wasTruncated: false)

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
            timing: RunnerTiming = quickTiming,
            layaExampleSaver: (@Sendable (LayaExample) async -> Void)? = nil,
            extraRunningApps: [RunningApp] = []
        ) -> TaskRunner {
            let runningApps =
                [
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
                        isFrontmost: frontmostBundleIdentifier == "com.apple.Passwords",
                        bundleURL: nil),
                ] + extraRunningApps
            let catalog = FakeAppCatalog(
                installed: [
                    InstalledApp(
                        name: "Testbed", fileName: "Testbed",
                        bundleIdentifier: "dev.straxs.Glim.Testbed", url: testbedURL)
                ]
                    + extraRunningApps.map { app in
                        InstalledApp(
                            name: app.name, fileName: app.name,
                            bundleIdentifier: app.bundleIdentifier,
                            url: app.bundleURL ?? URL(filePath: "/Applications/\(app.name).app"))
                    },
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
                isWatchdogAlive: { isWatchdogAlive },
                layaExampleSaver: layaExampleSaver)
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
    /// A target no control's wording fits, so the model has to pick one.
    static let clickFirstButtonPlan =
        #"{"kind":"task","steps":[{"action":"click","app":"Testbed","target":"the first button"}]}"#
    /// A target that is no control's exact label but whose wording fits only New Item.
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
                    Self.clickFirstButtonPlan, #"{"elementNumber":2,"blocked":false}"#,
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
            // The first retry says why; the rejected Archive is then no longer offered.
            let firstRetryPrompt = harness.model.requests.dropFirst(2).first?.userPrompt
            #expect(firstRetryPrompt?.contains("doesn't match the plan") == true)
            #expect(firstRetryPrompt?.contains("] Archive (") == false)
        }
    }

    /// Notes greys out New Note in its All iCloud view. Glim says so instead of making the
    /// model guess among the other controls.
    @Test func greyedOutPlannedControlStopsWithoutAskingTheModel() async throws {
        try await withTemporaryDirectory { directory in
            let table = ElementTable(
                elements: [Self.deleteButton, Self.archiveButton],
                handleIndexByElementNumber: [2: 2, 5: 5],
                readableText: String(repeating: "text ", count: 60), wasTruncated: false,
                disabledControlLabels: ["New Item"])
            let harness = makeHarness(
                in: directory, modelAnswers: [Self.clickNewItemLooselyPlan], table: table)

            let outcome = await harness.run(
                "click new item",
                runner: harness.makeRunner(policy: ChangingPolicy(Self.dangerOnlyPolicy)))

            #expect(
                outcome
                    == .blocked(
                        .targetDisabled(description: "the new item button", appName: "Testbed"),
                        stepNumber: 1))
            #expect(harness.model.requests.count == 1)
            #expect(harness.executor.performed.isEmpty)
        }
    }

    /// Glim never offers a window's close, minimize or zoom buttons, so a plan that clicks one
    /// stops at once with what to ask for instead, rather than making the model guess 3 times.
    @Test func clickOnAWindowButtonStopsWithGuidance() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(
                in: directory,
                modelAnswers: [
                    #"{"kind":"task","steps":[{"action":"click","app":"Testbed","target":"Close button"}]}"#
                ])

            let outcome = await harness.run("close testbed")

            #expect(
                outcome
                    == .blocked(.windowButtonTarget(description: "Close button"), stepNumber: 1))
            #expect(harness.model.requests.count == 1)
        }
    }

    /// Each step logs where its time went, so a slow step shows its bottleneck.
    @Test func eachStepLogsItsTiming() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(in: directory, modelAnswers: [Self.clickNewItemPlan])

            _ = await harness.run("click new item")

            let timing =
                try await harness.auditLog.readAllEvents()
                .filter { $0.kind == .stepTiming }.map(\.summary)
                .first { $0.hasPrefix("Click “New Item” in Testbed took ") } ?? ""
            #expect(timing.contains("read window"))
            #expect(timing.contains("pick"))
            #expect(timing.contains("act"))
        }
    }

    @Test func planningLogsItsTiming() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(in: directory, modelAnswers: [Self.clickNewItemPlan])

            _ = await harness.run("click new item")

            let summaries = try await harness.auditLog.readAllEvents()
                .filter { $0.kind == .stepTiming }.map(\.summary)
            #expect(summaries.contains { $0.hasPrefix("Planning took ") })
        }
    }

    /// Spotify's window once read as no controls at all. Asking the model to pick from an empty
    /// list only wastes three tries, and typing needs a field the gate can check, so a typing
    /// step stops and says what went wrong. (A click is looked for by sight instead.)
    @Test func windowWithNoControlsStopsATypingStepWithoutAskingTheModel() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(
                in: directory,
                modelAnswers: [
                    #"{"kind":"task","steps":[{"action":"typeText","app":"Testbed","target":"notes","text":"hi"}]}"#
                ],
                table: Self.emptyTable)

            let outcome = await harness.run("type hi")

            #expect(outcome == .blocked(.noControlsRead(appName: "Testbed"), stepNumber: 1))
            #expect(harness.model.requests.count == 1)
            #expect(harness.screenshotter.captures == 0)
            let kinds = try await harness.auditLog.readAllEvents().map(\.kind)
            #expect(kinds.contains(.controlsOffered))
        }
    }

    /// When no control can be picked, the log lists what Glim read from the window, so a
    /// control missing from the table (Notes' New Note) shows up in the Activity Log.
    @Test func blockedPickLogsTheControlsGlimSaw() async throws {
        try await withTemporaryDirectory { directory in
            let archivePick = #"{"elementNumber":5,"blocked":false}"#
            let harness = makeHarness(
                in: directory,
                modelAnswers: [
                    #"{"kind":"task","steps":[{"action":"click","app":"Testbed","target":"Compose"}]}"#,
                    archivePick, archivePick, archivePick,
                ])

            _ = await harness.run(
                "compose", runner: harness.makeRunner(policy: ChangingPolicy(Self.dangerOnlyPolicy))
            )

            let controlsEvents = try await harness.auditLog.readAllEvents()
                .filter { $0.kind == .controlsOffered }
            #expect(controlsEvents.count == 1)
            let summary = controlsEvents.first?.summary ?? ""
            #expect(summary.contains("[1] New Item (Button)"))
            #expect(summary.contains("[3] Notes field (TextField)"))
            #expect(summary.contains("[5] Archive (Button)"))
        }
    }

    /// Note titles are list-row labels, and one may hold a password. The Activity Log never
    /// keeps a secret-looking word, listed or cut by the limit.
    @Test func secretLookingLabelsAreMaskedInTheControlsLog() async throws {
        try await withTemporaryDirectory { directory in
            let secretRow = UIElementSnapshot.fixture(
                number: 6, role: "AXCell", label: "Wi-Fi: Qx7.pL2@vN9^k")
            let table = ElementTable(
                elements: Self.testbedTable.elements + [secretRow],
                handleIndexByElementNumber: Self.testbedTable.handleIndexByElementNumber,
                readableText: Self.testbedTable.readableText, wasTruncated: true,
                leftOutControlLabels: ["Router: Zt9!mK3#pQ8$"])
            let harness = makeHarness(
                in: directory,
                modelAnswers: [
                    #"{"kind":"task","steps":[{"action":"click","app":"Testbed","target":"Compose"}]}"#,
                    #"{"elementNumber":0,"blocked":true,"reason":"No compose button"}"#,
                ],
                table: table)

            _ = await harness.run("compose")

            let summary =
                try await harness.auditLog.readAllEvents()
                .first { $0.kind == .controlsOffered }?.summary ?? ""
            #expect(summary.contains("[6] Wi-Fi: [hidden] (Cell)"))
            #expect(summary.contains("Router: [hidden]"))
            #expect(!summary.contains("Qx7.pL2@vN9^k"))
            #expect(!summary.contains("Zt9!mK3#pQ8$"))
        }
    }

    @Test func controlsCutByTheLimitAreLogged() async throws {
        try await withTemporaryDirectory { directory in
            let table = ElementTable(
                elements: Self.testbedTable.elements,
                handleIndexByElementNumber: Self.testbedTable.handleIndexByElementNumber,
                readableText: Self.testbedTable.readableText, wasTruncated: true,
                leftOutControlLabels: ["Play My playlist"])
            let harness = makeHarness(
                in: directory,
                modelAnswers: [
                    #"{"kind":"task","steps":[{"action":"click","app":"Testbed","target":"Compose"}]}"#,
                    #"{"elementNumber":0,"blocked":true,"reason":"No compose button"}"#,
                ],
                table: table)

            _ = await harness.run("compose")

            let summary =
                try await harness.auditLog.readAllEvents()
                .first { $0.kind == .controlsOffered }?.summary ?? ""
            #expect(summary.contains("Left out by the limit: Play My playlist."))
        }
    }

    @Test func modelReportingNoMatchLogsTheControlsGlimSaw() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(
                in: directory,
                modelAnswers: [
                    #"{"kind":"task","steps":[{"action":"click","app":"Testbed","target":"Compose"}]}"#,
                    #"{"elementNumber":0,"blocked":true,"reason":"No compose button"}"#,
                ])

            _ = await harness.run("compose")

            let kinds = try await harness.auditLog.readAllEvents().map(\.kind)
            #expect(kinds.contains(.controlsOffered))
        }
    }

    /// With a saver attached, every step Laya answered is kept as a training example.
    @Test func stepReviewedByLayaIsSavedAsATrainingExample() async throws {
        try await withTemporaryDirectory { directory in
            let saved = SavedExamples()
            let harness = makeHarness(
                in: directory,
                modelAnswers: [Self.clickFirstButtonPlan, #"{"elementNumber":1,"blocked":false}"#])

            _ = await harness.run(
                "click the first button",
                runner: harness.makeRunner(
                    checkers: [ScriptedChecker(name: LayaChecker.checkerName, verdict: .agrees)],
                    layaExampleSaver: { example in saved.append(example) }))

            #expect(saved.examples.map(\.plannerPick) == ["1"])
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

    @Test(arguments: [
        (TaskOutcome.completed, "completed"),
        (
            .blocked(.limitReached(.tooManyTriesForStep(limit: 3)), stepNumber: 2),
            "blocked at step 2: "
        ),
        (.stopped(.humanTookOver), "stopped: "),
        (.failed("Notes has no open window."), "failed: Notes has no open window."),
    ])
    func outcomeIsWorded(outcome: TaskOutcome, expectedStart: String) {
        #expect(outcome.summary.hasPrefix(expectedStart))
        #expect(!outcome.summary.contains("GlimCore"))
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
                modelAnswers: [Self.clickFirstButtonPlan, badPick, badPick, badPick])

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
