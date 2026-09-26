/// Checks that the element the model chose fits the target the person approved.
///
/// Either every meaningful word of the approved target appears in the element's label, title or
/// description, or every word of the element appears in the target ("note body" fits a field
/// labelled "Note"). Sharing a single word is not enough: "Notes, 126 notes" is not "New Note". A mismatch is not a denial: the gate asks the person, showing both
/// ("Plan said New Note, AI chose Archive"). With no meaningful words to compare, the check
/// fails closed and asks.
public struct PlanMatcher: Sendable {
    /// Words that describe interfaces in general rather than naming a specific control.
    static let fillerWords: Set<String> = [
        "the", "a", "an", "button", "field", "menu", "item", "to", "of", "in", "on", "for", "and",
        "click", "tap", "press", "open",
    ]

    /// Business rule: words a plan uses for the main writing area of a document, note or
    /// message — which apps such as Notes leave unnamed. Only such a target matches an unnamed
    /// multi-line text area; "note title" does not.
    static let bodyWords: Set<String> = [
        "body", "content", "text", "area", "editor", "document", "message",
    ]
    private static let textAreaRole = "AXTextArea"

    /// Tunable: shortest word whose trailing "s" is treated as a plural ("notes" → "note").
    static let minimumLengthForPluralStripping = 4

    /// Creates a matcher.
    public init() {}

    /// Whether `element` plausibly is the control described by `targetDescription`.
    public func elementMatchesPlan(targetDescription: String, element: UIElementSnapshot) -> Bool {
        let plannedWords = Self.meaningfulWords(in: targetDescription)
        guard !plannedWords.isEmpty else {
            return false
        }
        if Self.isUnnamedTextArea(element) {
            return !plannedWords.isDisjoint(with: Self.bodyWords)
        }
        let elementTexts = [element.label, element.title, element.elementDescription]
            .compactMap { $0 }
        return textsMatchPlan(plannedWords: plannedWords, texts: elementTexts)
    }

    /// A multi-line text area with no name of its own, such as Notes' note body: it only has
    /// the generic label Glim gave it, so its words say nothing about which area it is.
    private static func isUnnamedTextArea(_ element: UIElementSnapshot) -> Bool {
        element.role == textAreaRole
            && element.label == ElementTableBuilder.untitledLabel(for: textAreaRole)
            && (element.title ?? "").isEmpty && (element.elementDescription ?? "").isEmpty
    }

    /// Whether a control labelled `text` plausibly is the one described by `targetDescription`.
    public func textMatchesPlan(targetDescription: String, text: String) -> Bool {
        let plannedWords = Self.meaningfulWords(in: targetDescription)
        guard !plannedWords.isEmpty else {
            return false
        }
        return textsMatchPlan(plannedWords: plannedWords, texts: [text])
    }

    private func textsMatchPlan(plannedWords: Set<String>, texts: [String]) -> Bool {
        let elementWords = texts.reduce(into: Set<String>()) { words, text in
            words.formUnion(Self.meaningfulWords(in: text))
        }
        guard !elementWords.isEmpty else {
            return false
        }
        return plannedWords.isSubset(of: elementWords) || elementWords.isSubset(of: plannedWords)
    }

    static func meaningfulWords(in text: String) -> Set<String> {
        let words = text.lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { !fillerWords.contains($0) }
            .map(singularForm)
        return Set(words)
    }

    static func singularForm(of word: String) -> String {
        let looksPlural =
            word.count >= minimumLengthForPluralStripping && word.hasSuffix("s")
            && !word.hasSuffix("ss")
        return looksPlural ? String(word.dropLast()) : word
    }
}
