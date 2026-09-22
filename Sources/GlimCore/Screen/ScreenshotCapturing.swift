import Foundation

/// Captures an app's front window as PNG data, kept in memory only.
public protocol ScreenshotCapturing: Sendable {
    /// Captures the app's frontmost on-screen window.
    func capturePNG(of app: ResolvedApp) async throws(ScreenReadingError) -> Data
}
