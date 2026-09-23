/// Reads the front window of an app into a ``ScreenSnapshot``.
public protocol ScreenReading: Sendable {
    /// Walks the app's focused window.
    func snapshotFrontWindow(of app: ResolvedApp) async throws(ScreenReadingError) -> ScreenSnapshot
    /// Texts of what pressing Return would activate (focused control, default button).
    func returnKeyTargetTexts(in app: ResolvedApp) async -> [String]
}
