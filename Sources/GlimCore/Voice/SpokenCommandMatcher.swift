/// Recognizes a spoken "stop" or "cancel".
///
/// While a task runs, any stop word stops it. When Glim is idle, only a bare stop command
/// ("stop", "Glim, stop") counts, so "stop the music" can still be a request.
public enum SpokenCommandMatcher {
    /// Business rule: words that stop Glim.
    static let stopWords: Set<String> = ["stop", "cancel"]
    /// The assistant's name, which may accompany a bare stop command.
    static let assistantName = "glim"

    /// Whether `transcript` is a stop command in the current situation.
    public static func isStopCommand(_ transcript: String, whileTaskIsRunning: Bool) -> Bool {
        let words = transcript.lowercased()
            .split { !$0.isLetter }
            .map(String.init)
        if whileTaskIsRunning {
            return words.contains(where: stopWords.contains)
        }
        let wordsWithoutName = words.filter { $0 != assistantName }
        return wordsWithoutName.count == 1 && wordsWithoutName.allSatisfy(stopWords.contains)
    }
}
