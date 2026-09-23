/// Speaks short status lines and answers.
public protocol Narrating: Sendable {
    /// Speaks `text` unless narration is muted.
    func say(_ text: String) async
    /// Stops speaking immediately (kill switch).
    func stopSpeaking() async
}
