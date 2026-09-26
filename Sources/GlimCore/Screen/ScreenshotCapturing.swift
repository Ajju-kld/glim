import CoreGraphics
import Foundation

/// One capture of an app's front window: the image and where the window was when it was taken.
public struct WindowCapture: Sendable, Equatable {
    /// The window as PNG data, kept in memory only.
    public let pngData: Data
    /// The window's frame in global screen points, top-left origin, at the moment of capture.
    public let windowFrame: CGRect

    /// Creates a capture.
    public init(pngData: Data, windowFrame: CGRect) {
        self.pngData = pngData
        self.windowFrame = windowFrame
    }
}

/// Captures an app's front window as PNG data, kept in memory only.
public protocol ScreenshotCapturing: Sendable {
    /// Captures the app's frontmost on-screen window together with its frame.
    func captureFrontWindow(of app: ResolvedApp) async throws(ScreenReadingError) -> WindowCapture
    /// Captures the whole main display as PNG data for screen chat, with every app `privacy`
    /// leaves out removed by the capture itself.
    func captureDisplay(leavingOut privacy: ScreenChatPrivacy) async throws(ScreenReadingError)
        -> Data
}

extension ScreenshotCapturing {
    /// Captures the app's frontmost on-screen window as PNG data.
    public func capturePNG(of app: ResolvedApp) async throws(ScreenReadingError) -> Data {
        try await captureFrontWindow(of: app).pngData
    }
}
