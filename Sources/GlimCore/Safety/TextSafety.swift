/// Detects characters that act like key presses when typed.
enum TextSafety {
    /// Whether `text` contains a newline, tab, line or paragraph separator, or another control
    /// character. Typed, these behave like Return or Tab — in a chat app a newline sends the
    /// message — so they would bypass the Return confirmation. Emoji joiners are allowed.
    static func containsKeyLikeCharacters(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.properties.generalCategory {
            case .control, .lineSeparator, .paragraphSeparator:
                true
            default:
                false
            }
        }
    }
}
