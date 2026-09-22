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
        #expect(request.responseSchema == PlannerSchemas.plan)
        #expect(request.imagesPNG.isEmpty)
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
            for: .click(appName: "Notes", target: "New Note"), goal: context.goal,
            among: [newNoteButton, noteBody])

        #expect(choice == .element(newNoteButton))
    }

    @Test func numberMissingFromTheTableIsAModelError() async {
        let model = FakeLanguageModel(answer: #"{"elementNumber":7,"blocked":false}"#)

        await #expect(throws: PlannerError.elementNumberNotInTable(7)) {
            _ = try await Planner(languageModel: model).pickTarget(
                for: .click(appName: "Notes", target: "New Note"), goal: context.goal,
                among: [newNoteButton])
        }
    }

    @Test func pickingAnIncompatibleElementIsAModelError() async {
        let model = FakeLanguageModel(answer: #"{"elementNumber":1,"blocked":false}"#)

        await #expect(throws: PlannerError.elementNumberNotInTable(1)) {
            _ = try await Planner(languageModel: model).pickTarget(
                for: .typeText(appName: "Notes", target: "body", text: "hi"), goal: context.goal,
                among: [newNoteButton, noteBody])
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
            for: .typeText(appName: "Notes", target: "body", text: "hi"), goal: context.goal,
            among: [newNoteButton, noteBody])

        let prompt = try #require(model.requests.first?.userPrompt)
        #expect(prompt.contains("[2] Note body (TextArea)"))
        #expect(!prompt.contains("New Note"))
    }

    @Test func retryTellsTheModelWhatWasWrong() async throws {
        let model = FakeLanguageModel(answer: #"{"elementNumber":1,"blocked":false}"#)

        _ = try await Planner(languageModel: model).pickTarget(
            for: .click(appName: "Notes", target: "New Note"), goal: context.goal,
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
