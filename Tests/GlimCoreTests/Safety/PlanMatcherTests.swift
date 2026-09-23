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
