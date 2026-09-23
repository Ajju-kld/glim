/// Hides words that look like passwords or keys before a training example is saved.
enum SecretMasker {
    /// Business rule: a word this long that mixes lowercase, uppercase, digits and symbols is
    /// treated as a secret ("Qx7.pL2@vN9^k"); names and ordinary words never mix all four.
    static let minimumSecretLength = 8
    static let replacement = "[hidden]"

    /// `text` with every secret-looking word replaced.
    static func masked(_ text: String) -> String {
        text.split(separator: " ", omittingEmptySubsequences: false)
            .map { word in looksSecret(word) ? replacement : String(word) }
            .joined(separator: " ")
    }

    private static func looksSecret(_ word: Substring) -> Bool {
        guard word.count >= minimumSecretLength else {
            return false
        }
        let hasLowercase = word.contains(where: \.isLowercase)
        let hasUppercase = word.contains(where: \.isUppercase)
        let hasDigit = word.contains(where: \.isNumber)
        let hasSymbol = word.contains { !$0.isLetter && !$0.isNumber }
        return hasLowercase && hasUppercase && hasDigit && hasSymbol
    }
}
