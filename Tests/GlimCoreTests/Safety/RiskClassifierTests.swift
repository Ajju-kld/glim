import Testing

@testable import GlimCore

extension RiskLevel {
    fileprivate var isForbidden: Bool {
        if case .forbidden = self { true } else { false }
    }

    fileprivate var needsConfirmation: Bool {
        if case .needsConfirmation = self { true } else { false }
    }
}

struct RiskClassifierTests {
    let classifier = RiskClassifier(wordLists: SafetyPolicy.safeDefaults.riskWords)

    @Test(arguments: [
        "Delete", "Delete Note", "Remove from Dock", "Empty Trash", "Buy Now", "Always Allow",
        "Erase All Content", "Sign Out", "Install Update",
    ])
    func dangerousLabelsAreForbidden(label: String) {
        #expect(classifier.classify([label]).isForbidden)
    }

    @Test(arguments: [
        "Move to Trash…", "Don’t Save", "Dont Save", "DON'T SAVE", "Sign-Out", "Sign\u{00A0}Out",
        "  delete  ", "LOG\tOUT",
    ])
    func typographicVariantsOfForbiddenPhrasesAreForbidden(label: String) {
        #expect(classifier.classify([label]).isForbidden)
    }

    @Test(arguments: ["Send", "Reply All", "Close Window", "Forward", "Accept", "Post"])
    func sendingLabelsNeedConfirmation(label: String) {
        #expect(classifier.classify([label]).needsConfirmation)
    }

    @Test(arguments: [
        "New Note", "Deleted Items", "Sender", "Postpone", "Closet", "Paying", "Search", "",
    ])
    func wholeWordMatchingKeepsSimilarWordsSafe(label: String) {
        #expect(classifier.classify([label]) == .safe)
    }

    @Test func forbiddenWinsOverConfirm() {
        #expect(classifier.classify(["Send and Delete"]) == .forbidden(matchedPhrase: "delete"))
    }

    @Test func anyDescribingTextCanMakeAControlForbidden() {
        #expect(classifier.classify(["🗑", "Remove item"]) == .forbidden(matchedPhrase: "remove"))
    }

    @Test func matchedPhraseIsReportedAsWritten() {
        #expect(classifier.classify(["Don’t Save"]) == .forbidden(matchedPhrase: "don't save"))
    }

    @Test func blankPhrasesInEditedListsAreIgnored() {
        let editedLists = RiskWordLists(forbidden: ["", "   ", "---"], confirm: [])
        let classifierWithBlanks = RiskClassifier(wordLists: editedLists)

        #expect(classifierWithBlanks.classify(["anything at all"]) == .safe)
    }
}

struct RiskClassifierFoldingTests {
    let classifier = RiskClassifier(wordLists: SafetyPolicy.safeDefaults.riskWords)

    @Test(arguments: ["Délete", "DÉLÈTE", "ｄｅｌｅｔｅ", "Ｓｉｇｎ Ｏｕｔ", "Érase"])
    func accentsAndFullWidthLettersAreFoldedBeforeMatching(label: String) {
        guard case .forbidden = classifier.classify([label]) else {
            Issue.record("Expected “\(label)” to be forbidden")
            return
        }
    }

    @Test(arguments: SafetyDefaults.forbiddenPhrases)
    func everyDefaultForbiddenPhraseIsForbidden(phrase: String) {
        guard case .forbidden = classifier.classify([phrase.capitalized]) else {
            Issue.record("Expected “\(phrase)” to be forbidden")
            return
        }
    }

    @Test(arguments: SafetyDefaults.confirmPhrases)
    func everyDefaultConfirmPhraseAsks(phrase: String) {
        guard case .needsConfirmation = classifier.classify([phrase.uppercased()]) else {
            Issue.record("Expected “\(phrase)” to need confirmation")
            return
        }
    }
}
