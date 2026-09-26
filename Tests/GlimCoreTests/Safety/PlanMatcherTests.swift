import Testing

@testable import GlimCore

struct PlanMatcherTests {
    let matcher = PlanMatcher()

    @Test func exactLabelMatches() {
        let button = UIElementSnapshot.fixture(label: "New Note")

        #expect(matcher.elementMatchesPlan(targetDescription: "New Note", element: button))
    }

    @Test func unrelatedLabelDoesNotMatch() {
        let button = UIElementSnapshot.fixture(label: "Archive")

        #expect(!matcher.elementMatchesPlan(targetDescription: "New Note", element: button))
    }

    /// Sharing one word is not enough: the Notes folder row "Notes, 126 notes" shares "note"
    /// with "New Note" but is not it.
    @Test func rowSharingOneWordIsNotTheButton() {
        let folderRow = UIElementSnapshot.fixture(role: "AXRow", label: "Notes, 126 notes")

        #expect(!matcher.elementMatchesPlan(targetDescription: "New Note", element: folderRow))
    }

    @Test func plainLabelIsMatchedAgainstThePlan() {
        #expect(matcher.textMatchesPlan(targetDescription: "New Note", text: "New Note"))
        #expect(!matcher.textMatchesPlan(targetDescription: "New Note", text: "Notes, 126 notes"))
    }

    @Test func labelWithinThePlanWordingMatches() {
        let field = UIElementSnapshot.fixture(role: "AXTextArea", label: "Note")

        #expect(matcher.elementMatchesPlan(targetDescription: "note body", element: field))
    }

    @Test func pluralAndSingularMatch() {
        let list = UIElementSnapshot.fixture(label: "Note")

        #expect(matcher.elementMatchesPlan(targetDescription: "notes list", element: list))
    }

    @Test func matchingIgnoresCase() {
        let button = UIElementSnapshot.fixture(label: "new note")

        #expect(matcher.elementMatchesPlan(targetDescription: "NEW NOTE", element: button))
    }

    @Test func titleOrDescriptionCanMatch() {
        let iconButton = UIElementSnapshot.fixture(label: "✎", elementDescription: "Compose")

        #expect(matcher.elementMatchesPlan(targetDescription: "compose", element: iconButton))
    }

    @Test func fillerOnlyTargetNeverMatches() {
        let button = UIElementSnapshot.fixture(label: "Button")

        #expect(!matcher.elementMatchesPlan(targetDescription: "the button", element: button))
    }

    @Test func emptyLabelNeverMatches() {
        let unlabelled = UIElementSnapshot.fixture(label: "")

        #expect(!matcher.elementMatchesPlan(targetDescription: "New Note", element: unlabelled))
    }

    @Test func differentWordingAsksThePerson() {
        let button = UIElementSnapshot.fixture(label: "New Message")

        #expect(!matcher.elementMatchesPlan(targetDescription: "compose", element: button))
    }
}

/// Notes' note body (and other editors) has no name of its own, so it is listed as "Untitled
/// text area"; a plan that asks to type into a "note body" must still find it.
struct PlanMatcherUnnamedBodyTests {
    let matcher = PlanMatcher()
    let unnamedTextArea = UIElementSnapshot.fixture(
        number: 7, role: "AXTextArea", label: ElementTableBuilder.untitledLabel(for: "AXTextArea"))
    let unnamedTextField = UIElementSnapshot.fixture(
        number: 8, role: "AXTextField",
        label: ElementTableBuilder.untitledLabel(for: "AXTextField"))

    @Test(arguments: ["note body", "body", "message body", "the note content", "text area"])
    func bodyTargetMatchesAnUnnamedTextArea(target: String) {
        #expect(matcher.elementMatchesPlan(targetDescription: target, element: unnamedTextArea))
    }

    @Test func titleTargetDoesNotMatchTheBody() {
        #expect(
            !matcher.elementMatchesPlan(targetDescription: "note title", element: unnamedTextArea))
    }

    /// A single-line field is not a body.
    @Test func bodyTargetDoesNotMatchAnUnnamedTextField() {
        #expect(
            !matcher.elementMatchesPlan(targetDescription: "note body", element: unnamedTextField))
    }

    /// A text area with its own name is judged by that name, as before.
    @Test func namedTextAreaIsJudgedByItsName() {
        let commentBox = UIElementSnapshot.fixture(
            number: 9, role: "AXTextArea", label: "Comment")

        #expect(!matcher.elementMatchesPlan(targetDescription: "note body", element: commentBox))
    }

    /// Notes' layout: the planner picks the body without asking the model.
    @Test func plannerTypesIntoTheNoteBodyWithoutTheModel() async throws {
        let model = FakeLanguageModel(answers: [])
        let searchField = UIElementSnapshot.fixture(
            number: 1, role: "AXTextField", label: "Search")

        let choice = try await Planner(languageModel: model).pickTarget(
            for: .typeText(appName: "Notes", target: "note body", text: "hello world"),
            goal: "write hello world", among: [searchField, unnamedTextField, unnamedTextArea])

        #expect(choice == .element(unnamedTextArea, pickedBy: .planMatch))
        #expect(model.requests.isEmpty)
    }
}
