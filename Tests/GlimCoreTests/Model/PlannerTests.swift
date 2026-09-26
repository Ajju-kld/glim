import Foundation
import Testing

@testable import GlimCore

struct PlannerTests {
    let context = PlanningContext(
        goal: "open notes and write buy milk",
        frontAppName: "Finder",
        windowTitle: "Downloads",
        elementLabels: ["New Folder", "Search"],
        installedAppNames: ["Notes", "TextEdit"],
        runningAppNames: ["Finder"])

    let newNoteButton = UIElementSnapshot.fixture(number: 1, label: "New Note")
    let noteBody = UIElementSnapshot.fixture(number: 2, role: "AXTextArea", label: "Note body")
    let noteTitle = UIElementSnapshot.fixture(number: 3, role: "AXTextField", label: "Title")

    // MARK: - Plans

    @Test func taskAnswerBecomesTypedSteps() async throws {
        let model = FakeLanguageModel(
            answer: """
                {"kind":"task","steps":[
                {"action":"openApp","app":"Notes"},
                {"action":"click","app":"Notes","target":"New Note"},
                {"action":"typeText","app":"Notes","target":"note body","text":"buy milk"},
                {"action":"pressKey","app":"Notes","key":"escape"},
                {"action":"scroll","app":"Notes","direction":"down"},
                {"action":"moveWindow","app":"Notes","preset":"leftHalf"},
                {"action":"minimizeWindow","app":"Slack"},
                {"action":"restoreWindow","app":"Slack"},
                {"action":"switchApp","app":"Notes"},
                {"action":"quitApp","app":"TextEdit"},
                {"action":"speak","text":"Done"}]}
                """)

        let result = try await Planner(languageModel: model).makePlan(for: context)

        #expect(
            result
                == .task(
                    Plan(
                        goal: "open notes and write buy milk",
                        steps: [
                            .openApp(appName: "Notes"),
                            .click(appName: "Notes", target: "New Note"),
                            .typeText(appName: "Notes", target: "note body", text: "buy milk"),
                            .pressKey(appName: "Notes", key: .escape),
                            .scroll(appName: "Notes", direction: .down),
                            .moveWindow(appName: "Notes", preset: .leftHalf),
                            .minimizeWindow(appName: "Slack"),
                            .restoreWindow(appName: "Slack"),
                            .switchApp(appName: "Notes"),
                            .quitApp(appName: "TextEdit"),
                            .speak(text: "Done"),
                        ])))
    }

    @Test func questionAnswerIsRecognized() async throws {
        let model = FakeLanguageModel(answer: #"{"kind":"question","steps":[]}"#)

        #expect(try await Planner(languageModel: model).makePlan(for: context) == .question)
    }

    @Test(arguments: [
        (#"{"kind":"task","steps":[{"action":"runShell","app":"Terminal"}]}"#, 1),
        (#"{"kind":"task","steps":[{"action":"openApp"}]}"#, 1),
        (#"{"kind":"task","steps":[{"action":"openApp","app":"  "}]}"#, 1),
        (
            #"{"kind":"task","steps":[{"action":"openApp","app":"Notes"},{"action":"pressKey","app":"Notes","key":"delete"}]}"#,
            2
        ),
        (#"{"kind":"task","steps":[{"action":"click","app":"Notes"}]}"#, 1),
        (#"{"kind":"task","steps":[{"action":"moveWindow","app":"Notes","preset":"x=0,y=0"}]}"#, 1),
    ])
    func invalidStepsAreModelErrors(answer: String, badStepNumber: Int) async {
        let planner = Planner(languageModel: FakeLanguageModel(answer: answer))

        do throws(PlannerError) {
            _ = try await planner.makePlan(for: context)
            Issue.record("Expected an invalid step error")
        } catch {
            guard case .invalidStep(let stepNumber, _) = error else {
                Issue.record("Expected invalidStep, got \(error)")
                return
            }
            #expect(stepNumber == badStepNumber)
        }
    }

    @Test(arguments: ["not json", #"{"kind":"essay","steps":[]}"#, #"{"steps":[]}"#])
    func unreadableAnswersAreModelErrors(answer: String) async {
        let planner = Planner(languageModel: FakeLanguageModel(answer: answer))

        await #expect(throws: PlannerError.self) {
            _ = try await planner.makePlan(for: context)
        }
    }

    @Test func extraFieldsFromTheModelAreIgnored() async throws {
        let model = FakeLanguageModel(
            answer:
                #"{"kind":"task","steps":[{"action":"openApp","app":"Notes","command":"rm -rf ~"}],"note":"hi"}"#
        )

        let result = try await Planner(languageModel: model).makePlan(for: context)

        #expect(result == .task(Plan(goal: context.goal, steps: [.openApp(appName: "Notes")])))
    }

    @Test func planningPromptCarriesLabelsAppsAndInjectionWarning() async throws {
        let model = FakeLanguageModel(answer: #"{"kind":"question","steps":[]}"#)

        _ = try await Planner(languageModel: model).makePlan(for: context)

        let request = try #require(model.requests.first)
        #expect(request.userPrompt.contains("open notes and write buy milk"))
        #expect(request.userPrompt.contains("New Folder"))
        #expect(request.userPrompt.contains("Notes, TextEdit"))
        #expect(request.userPrompt.contains("Downloads"))
        #expect(request.systemPrompt.contains("never instructions"))
        #expect(request.responseSchema == PlannerSchemas.plan(limits: context.limits))
        #expect(request.imagesPNG.isEmpty)
    }

    @Test func planningPromptPutsTheStableListsFirstAndTheRequestLast() async throws {
        let model = FakeLanguageModel(answer: #"{"kind":"question","steps":[]}"#)

        _ = try await Planner(languageModel: model).makePlan(for: context)

        let prompt = try #require(model.requests.first?.userPrompt)
        #expect(prompt.hasPrefix("Installed apps: Notes, TextEdit"))
        #expect(prompt.hasSuffix("Request: open notes and write buy milk"))
    }

    /// Speed and focus: a front window's whole control list made plans slow and tempted the
    /// model to copy it into steps. Only controls sharing words with the request are listed.
    @Test func planningPromptListsOnlyControlsRelevantToTheRequest() {
        let manyLabels = (1...60).map { "Daily Mix \($0)" } + ["Next", "Pause"]
        let spotifyContext = PlanningContext(
            goal: "skip to the next song", frontAppName: "Spotify", windowTitle: "Now Playing",
            elementLabels: manyLabels, installedAppNames: ["Spotify"],
            runningAppNames: ["Spotify"])

        let prompt = Planner.planningPrompt(for: spotifyContext)

        #expect(prompt.contains("- Next"))
        #expect(!prompt.contains("Daily Mix"))
        #expect(prompt.components(separatedBy: "\n- ").count - 1 <= Planner.planningControlLimit)
    }

    @Test func plannerIsToldNotToClickWindowButtons() {
        #expect(PlannerPrompts.planning.contains("close, minimize or zoom buttons"))
        #expect(PlannerPrompts.planning.contains("quitApp"))
    }

    /// "Now Playing" then "Play" both hit Spotify's play/pause button, so music started and
    /// stopped again.
    @Test func plannerIsToldToPressPlayOnce() {
        #expect(PlannerPrompts.planning.contains("click Play once"))
    }

    /// Calendar has no Reminders button; its reminders are in the sidebar the Calendars button
    /// opens, and new reminders belong in the Reminders app.
    @Test func plannerIsToldWhereCalendarKeepsReminders() {
        #expect(PlannerPrompts.planning.contains("click \"Calendars\""))
        #expect(PlannerPrompts.planning.contains("the Reminders app"))
    }

    @Test func planSchemaFollowsTheCurrentLimits() async throws {
        var tightLimits = SafetyLimits.safeDefaults
        tightLimits.maximumActionsPerTask = 5
        let tightContext = PlanningContext(
            goal: context.goal, frontAppName: nil, windowTitle: nil, elementLabels: [],
            installedAppNames: ["Notes"], runningAppNames: [], limits: tightLimits)
        let model = FakeLanguageModel(answer: #"{"kind":"question","steps":[]}"#)

        _ = try await Planner(languageModel: model).makePlan(for: tightContext)

        #expect(model.requests.first?.responseSchema == PlannerSchemas.plan(limits: tightLimits))
    }

    @Test func modelFailureIsPassedOn() async {
        let model = FakeLanguageModel(answers: [
            .failure(.modelNotInstalled(modelName: "qwen3-vl:8b"))
        ])

        await #expect(throws: PlannerError.model(.modelNotInstalled(modelName: "qwen3-vl:8b"))) {
            _ = try await Planner(languageModel: model).makePlan(for: context)
        }
    }

    // MARK: - Target picking

    @Test func pickedNumberBecomesTheElement() async throws {
        let model = FakeLanguageModel(answer: #"{"elementNumber":1,"blocked":false}"#)

        let choice = try await Planner(languageModel: model).pickTarget(
            for: .click(appName: "Notes", target: "the button to start writing"),
            goal: context.goal, among: [newNoteButton, noteBody])

        #expect(choice == .element(newNoteButton, pickedBy: .languageModel))
        #expect(model.requests.count == 1)
    }

    @Test func exactLabelMatchIsPickedWithoutAskingTheModel() async throws {
        let model = FakeLanguageModel(answers: [])

        let choice = try await Planner(languageModel: model).pickTarget(
            for: .click(appName: "Notes", target: " new NOTE "), goal: context.goal,
            among: [newNoteButton, noteBody])

        #expect(choice == .element(newNoteButton, pickedBy: .exactLabel))
        #expect(model.requests.isEmpty)
    }

    /// "Click the address bar": a field is a valid click target, picked by its label.
    @Test func clickOnAFieldByItsLabelIsPickedWithoutAskingTheModel() async throws {
        let model = FakeLanguageModel(answers: [])

        let choice = try await Planner(languageModel: model).pickTarget(
            for: .click(appName: "Notes", target: "Title"), goal: context.goal,
            among: [newNoteButton, noteTitle])

        #expect(choice == .element(noteTitle, pickedBy: .exactLabel))
        #expect(model.requests.isEmpty)
    }

    @Test func twoControlsWithTheSameLabelStillAskTheModel() async throws {
        let secondNewNoteButton = UIElementSnapshot.fixture(number: 3, label: "New Note")
        let model = FakeLanguageModel(answer: #"{"elementNumber":3,"blocked":false}"#)

        let choice = try await Planner(languageModel: model).pickTarget(
            for: .click(appName: "Notes", target: "New Note"), goal: context.goal,
            among: [newNoteButton, secondNewNoteButton])

        #expect(choice == .element(secondNewNoteButton, pickedBy: .languageModel))
        #expect(model.requests.count == 1)
    }

    @Test func exactLabelOfAnIncompatibleControlIsNotPicked() async throws {
        let model = FakeLanguageModel(answer: #"{"elementNumber":2,"blocked":false}"#)

        let choice = try await Planner(languageModel: model).pickTarget(
            for: .typeText(appName: "Notes", target: "New Note", text: "hi"), goal: context.goal,
            among: [newNoteButton, noteBody, noteTitle])

        #expect(choice == .element(noteBody, pickedBy: .languageModel))
        #expect(model.requests.count == 1)
    }

    /// Speed: the same wording rule that accepts a model's pick picks the only match itself.
    @Test func onlyControlMatchingThePlanIsPickedWithoutAskingTheModel() async throws {
        let playButton = UIElementSnapshot.fixture(number: 4, label: "Play")
        let pauseButton = UIElementSnapshot.fixture(number: 5, label: "Pause")
        let model = FakeLanguageModel(answers: [])

        let choice = try await Planner(languageModel: model).pickTarget(
            for: .click(appName: "Spotify", target: "Play button"), goal: "play music",
            among: [pauseButton, playButton])

        #expect(choice == .element(playButton, pickedBy: .planMatch))
        #expect(model.requests.isEmpty)
    }

    @Test func confidentLayaPickIsMarkedAsLayasAndAskedWithTheScreen() async throws {
        let playButton = UIElementSnapshot.fixture(number: 4, label: "Play")
        let pauseButton = UIElementSnapshot.fixture(number: 5, label: "Pause")
        let model = FakeLanguageModel(answers: [])
        let layaTransport = FakeHTTPTransport(replies: [
            .response(
                statusCode: 200,
                body: #"{"answers":{"target":{"choice":"5","probabilities":{"4":0.05,"5":0.95}}}}"#)
        ])

        let choice = try await Planner(
            languageModel: model, fastPicker: LayaPicker(transport: layaTransport)
        ).pickTarget(
            for: .click(appName: "Spotify", target: "the thing that stops music"),
            goal: "stop the music", among: [playButton, pauseButton], appName: "Spotify",
            windowTitle: "Spotify Premium")

        #expect(choice == .element(pauseButton, pickedBy: .laya))
        #expect(model.requests.isEmpty)
        let layaRequest = try #require(layaTransport.sentRequests.first)
        let state = try #require(try jsonObject(of: layaRequest)["state"] as? [String: Any])
        #expect(state["app"] as? String == "Spotify")
        #expect(state["windowTitle"] as? String == "Spotify Premium")
    }

    /// Speed: reading the prompt is most of a pick's time, so the model first sees only the
    /// controls closest to the plan's wording, and every control after a rejected answer.
    @Test func pickPromptOffersAShortlistThenEveryControlOnRetry() async throws {
        let buttons = (1...40).map { number in
            UIElementSnapshot.fixture(number: number, label: "Playlist \(number)")
        }
        let model = FakeLanguageModel(answers: [
            .success(#"{"elementNumber":3,"blocked":false}"#),
            .success(#"{"elementNumber":3,"blocked":false}"#),
        ])
        let planner = Planner(languageModel: model)

        _ = try await planner.pickTarget(
            for: .click(appName: "Spotify", target: "Compose"), goal: "compose", among: buttons)
        _ = try await planner.pickTarget(
            for: .click(appName: "Spotify", target: "Compose"), goal: "compose", among: buttons,
            retryNote: "Pick again.")

        let listedCounts = model.requests.map { request in
            request.userPrompt.components(separatedBy: "(Button)").count - 1
        }
        #expect(listedCounts == [Planner.pickShortlistLimit, 40])
    }

    @Test func pickAnswerLengthIsCappedShort() async throws {
        let model = FakeLanguageModel(answer: #"{"elementNumber":1,"blocked":false}"#)

        _ = try await Planner(languageModel: model).pickTarget(
            for: .click(appName: "Notes", target: "Compose"), goal: context.goal,
            among: [newNoteButton])

        #expect(model.requests.first?.maximumAnswerTokens == Planner.pickAnswerTokenLimit)
    }

    @Test func numberMissingFromTheTableIsAModelError() async {
        let model = FakeLanguageModel(answer: #"{"elementNumber":7,"blocked":false}"#)

        await #expect(throws: PlannerError.elementNumberNotInTable(7)) {
            _ = try await Planner(languageModel: model).pickTarget(
                for: .click(appName: "Notes", target: "the compose button"), goal: context.goal,
                among: [newNoteButton])
        }
    }

    @Test func pickingAnIncompatibleElementIsAModelError() async {
        let model = FakeLanguageModel(answer: #"{"elementNumber":1,"blocked":false}"#)

        await #expect(throws: PlannerError.elementNumberNotInTable(1)) {
            _ = try await Planner(languageModel: model).pickTarget(
                for: .typeText(appName: "Notes", target: "comment", text: "hi"), goal: context.goal,
                among: [newNoteButton, noteBody, noteTitle])
        }
    }

    @Test func modelCanReportTheTargetMissing() async throws {
        let model = FakeLanguageModel(
            answer: #"{"elementNumber":0,"blocked":true,"reason":"No such button"}"#)

        let choice = try await Planner(languageModel: model).pickTarget(
            for: .click(appName: "Notes", target: "Share"), goal: context.goal,
            among: [newNoteButton])

        #expect(choice == .blocked(reason: "No such button"))
    }

    @Test func pickPromptListsOnlyCompatibleElements() async throws {
        let model = FakeLanguageModel(answer: #"{"elementNumber":2,"blocked":false}"#)

        _ = try await Planner(languageModel: model).pickTarget(
            for: .typeText(appName: "Notes", target: "comment", text: "hi"), goal: context.goal,
            among: [newNoteButton, noteBody, noteTitle])

        let prompt = try #require(model.requests.first?.userPrompt)
        #expect(prompt.contains("[2] Note body (TextArea)"))
        #expect(!prompt.contains("New Note"))
    }

    @Test func retryTellsTheModelWhatWasWrong() async throws {
        let model = FakeLanguageModel(answer: #"{"elementNumber":1,"blocked":false}"#)

        _ = try await Planner(languageModel: model).pickTarget(
            for: .click(appName: "Notes", target: "the compose button"), goal: context.goal,
            among: [newNoteButton], retryNote: "Element 7 is not in the list.")

        let prompt = try #require(model.requests.first?.userPrompt)
        #expect(prompt.contains("Your previous answer was rejected: Element 7 is not in the list."))
    }

    // MARK: - Questions

    @Test func questionIsAnsweredFromScreenText() async throws {
        let model = FakeLanguageModel(answer: #"{"answer":"You have two notes open."}"#)

        let answer = try await Planner(languageModel: model).answerQuestion(
            "what's on my screen", screenText: "Groceries\nIdeas", screenshotPNG: nil)

        #expect(answer == "You have two notes open.")
        #expect(model.requests.first?.userPrompt.contains("Groceries") == true)
    }

    @Test func questionCanUseAScreenshot() async throws {
        let model = FakeLanguageModel(answer: #"{"answer":"A photo of a cat."}"#)
        let screenshot = Data([1, 2, 3])

        _ = try await Planner(languageModel: model).answerQuestion(
            "what's this", screenText: nil, screenshotPNG: screenshot)

        #expect(model.requests.first?.imagesPNG == [screenshot])
    }
}

struct PlannerSchemaTests {
    func encodedPlanSchema(limits: SafetyLimits = .safeDefaults) throws -> [String: Any] {
        let data = try JSONEncoder().encode(PlannerSchemas.plan(limits: limits))
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    /// The model writes fields in schema order. With `action` later in a step, qwen3-vl commits
    /// to a step before choosing what it does and loops (openApp, switchApp, openApp…) until the
    /// token cap; with `steps` before `kind`, it plans before deciding it is a task at all.
    @Test func kindComesFirstAndEveryStepStartsWithItsAction() throws {
        let text = String(
            decoding: try PlannerSchemas.plan(limits: .safeDefaults).jsonData(), as: UTF8.self)

        #expect(text.hasPrefix(#"{"type":"object","properties":{"kind":"#))
        #expect(
            text.components(separatedBy: #""properties":{"action":"#).count - 1
                == ActionKind.allCases.count)
    }

    /// Ollama enforces `maxItems` and `maxLength` while generating, so a model stuck repeating
    /// itself stops at the limits instead of running until the request times out.
    @Test func stepsAndTypedTextAreBoundedByTheLimits() throws {
        var limits = SafetyLimits.safeDefaults
        limits.maximumActionsPerTask = 7
        limits.maximumTypedTextLength = 42
        let schema = try encodedPlanSchema(limits: limits)
        let steps = try #require(
            (schema["properties"] as? [String: Any])?["steps"] as? [String: Any])
        let variants = try #require(
            (steps["items"] as? [String: Any])?["anyOf"] as? [[String: Any]])
        let typeTextProperties = try #require(
            variants.first {
                ((($0["properties"] as? [String: Any])?["action"] as? [String: Any])?["enum"]
                    as? [String]) == ["typeText"]
            }?["properties"] as? [String: Any])

        #expect(steps["maxItems"] as? Int == 7)
        #expect((typeTextProperties["text"] as? [String: Any])?["maxLength"] as? Int == 42)
        #expect(
            (typeTextProperties["target"] as? [String: Any])?["maxLength"] as? Int
                == PlannerSchemas.maximumNameLength)
    }

    @Test func everyActionHasAVariantRequiringItsFields() throws {
        let schema = try encodedPlanSchema()
        let steps = try #require(
            (schema["properties"] as? [String: Any])?["steps"] as? [String: Any])
        let variants = try #require(
            (steps["items"] as? [String: Any])?["anyOf"] as? [[String: Any]])
        var requiredFieldsByAction: [String: Set<String>] = [:]
        for variant in variants {
            let action = try #require(
                ((variant["properties"] as? [String: Any])?["action"] as? [String: Any])?["enum"]
                    as? [String])
            requiredFieldsByAction[try #require(action.first)] = Set(
                try #require(variant["required"] as? [String]))
        }

        #expect(Set(requiredFieldsByAction.keys) == Set(ActionKind.allCases.map(\.rawValue)))
        #expect(requiredFieldsByAction["click"] == ["action", "app", "target"])
        #expect(requiredFieldsByAction["typeText"] == ["action", "app", "target", "text"])
        #expect(requiredFieldsByAction["moveWindow"] == ["action", "app", "preset"])
        #expect(requiredFieldsByAction["pressKey"] == ["action", "app", "key"])
        #expect(requiredFieldsByAction["scroll"] == ["action", "app", "direction"])
        #expect(requiredFieldsByAction["speak"] == ["action", "text"])
        #expect(requiredFieldsByAction["openApp"] == ["action", "app"])
    }
}
