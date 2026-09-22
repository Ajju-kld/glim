/// Detects characters that are unsafe to type.
enum TextSafety {
    /// The zero-width joiner that builds emoji like 👨‍👩‍👧.
    private static let zeroWidthJoiner: Unicode.Scalar = "\u{200D}"
    /// Tag characters that build flag emoji such as 🏴󠁧󠁢󠁳󠁣󠁴󠁿.
    private static let emojiTagCharacters: ClosedRange<UInt32> = 0xE0020...0xE007F

    /// Whether `text` contains a character that is unsafe to type:
    /// - newlines, tabs and other control characters, which act like Return or Tab (in a chat
    ///   app a newline sends the message, bypassing the Return confirmation);
    /// - invisible formatting characters (bidi overrides, zero-width spaces), which would make the
    ///   approval panel show different text from what is typed.
    ///
    /// Emoji joiners and flag tags are allowed.
    static func containsUnsafeCharacters(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.properties.generalCategory {
            case .control, .lineSeparator, .paragraphSeparator:
                true
            case .format:
                scalar != zeroWidthJoiner && !emojiTagCharacters.contains(scalar.value)
            default:
                false
            }
        }
    }
}
