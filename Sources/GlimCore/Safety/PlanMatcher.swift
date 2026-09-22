/// Checks that the element the model chose fits the target the person approved.
///
/// The chosen element's label, title or description must share at least one meaningful word
/// with the approved target. A mismatch is not a denial: the gate asks the person, showing both
/// ("Plan said New Note, AI chose Archive"). With no meaningful words to compare, the check
/// fails closed and asks.
public struct PlanMatcher: Sendable {
    /// Words that describe interfaces in general rather than naming a specific control.
    static let fillerWords: Set<String> = [
        "the", "a", "an", "button", "field", "menu", "item", "to", "of", "in", "on", "for", "and",
        "click", "tap", "press", "open",
    ]

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
        let elementTexts = [element.label, element.title, element.elementDescription]
            .compactMap { $0 }
        let elementWords = elementTexts.reduce(into: Set<String>()) { words, text in
            words.formUnion(Self.meaningfulWords(in: text))
        }
        return !plannedWords.isDisjoint(with: elementWords)
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
