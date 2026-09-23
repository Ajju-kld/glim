import Foundation

/// Finds Forbidden and Confirm phrases in the texts that describe a control.
///
/// Matching is case-insensitive and whole-word: "Delete Note" and "Move to Trash…" match, but
/// "Deleted Items" and "Postpone" do not. Apostrophes are dropped and every other run of
/// punctuation or whitespace becomes one space, so "Don’t Save", "Dont Save" and "SIGN-OUT"
/// still match. Accents and full-width letters are folded first ("Délete", "ｄｅｌｅｔｅ").
/// Forbidden phrases win over Confirm phrases.
public struct RiskClassifier: Sendable {
    private struct Phrase: Sendable {
        let original: String
        let normalized: String
    }

    /// Straight, curly and modifier apostrophes; dropped so "don't" and "dont" compare equal.
    private static let apostropheVariants: Set<Character> = ["'", "’", "‘", "ʼ", "`", "´"]

    private let forbiddenPhrases: [Phrase]
    private let confirmPhrases: [Phrase]

    /// Creates a classifier for the given word lists. Phrases with no letters or digits are
    /// ignored, so a blank entry in an edited list can't match everything.
    public init(wordLists: RiskWordLists) {
        forbiddenPhrases = Self.phrases(from: wordLists.forbidden)
        confirmPhrases = Self.phrases(from: wordLists.confirm)
    }

    /// Classifies a control from every text that describes it.
    public func classify(_ texts: [String]) -> RiskLevel {
        let normalizedTexts = texts.map(Self.normalize)
        if let phrase = Self.firstPhrase(of: forbiddenPhrases, foundIn: normalizedTexts) {
            return .forbidden(matchedPhrase: phrase)
        }
        if let phrase = Self.firstPhrase(of: confirmPhrases, foundIn: normalizedTexts) {
            return .needsConfirmation(matchedPhrase: phrase)
        }
        return .safe
    }

    /// Folds compatibility forms, accents, width and case, drops apostrophes, and joins the
    /// remaining letter-and-digit words with single spaces, padded on both ends so phrases match
    /// whole words only.
    static func normalize(_ text: String) -> String {
        let foldedText = text.precomposedStringWithCompatibilityMapping
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil
            )
            .lowercased()
        var words: [String] = []
        var currentWord = ""
        for character in foldedText where !apostropheVariants.contains(character) {
            if character.isLetter || character.isNumber {
                currentWord.append(character)
            } else if !currentWord.isEmpty {
                words.append(currentWord)
                currentWord = ""
            }
        }
        if !currentWord.isEmpty {
            words.append(currentWord)
        }
        return " " + words.joined(separator: " ") + " "
    }

    private static func phrases(from rawPhrases: [String]) -> [Phrase] {
        rawPhrases.compactMap { rawPhrase in
            let normalized = normalize(rawPhrase)
            let hasWords = normalized.contains { !$0.isWhitespace }
            return hasWords ? Phrase(original: rawPhrase, normalized: normalized) : nil
        }
    }

    private static func firstPhrase(
        of phrases: [Phrase], foundIn normalizedTexts: [String]
    ) -> String? {
        let matchingPhrase = phrases.first { phrase in
            normalizedTexts.contains { normalizedText in
                normalizedText.contains(phrase.normalized)
            }
        }
        return matchingPhrase?.original
    }
}
