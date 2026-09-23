import CoreGraphics
import Foundation
import ImageIO
import ScreenCaptureKit
import UniformTypeIdentifiers

/// Captures one window with ScreenCaptureKit for the vision fallback.
///
/// The image never touches the disk: it is encoded to PNG in memory and handed to the model.
/// Screen Recording permission is requested only the first time a screenshot is needed.
public struct WindowScreenshotter: ScreenshotCapturing {
    /// Tunable: longest side of a screenshot sent to the model; bigger costs time and memory.
    public static let maximumPixelDimension = 1_280
    /// Tunable: windows are captured at Retina scale before fitting.
    static let captureScale: CGFloat = 2

    private let mayPromptForPermission: Bool

    /// Creates a screenshotter.
    ///
    /// - Parameter mayPromptForPermission: Whether a missing permission may show the system
    ///   prompt (true in the app, false in tests).
    public init(mayPromptForPermission: Bool = true) {
        self.mayPromptForPermission = mayPromptForPermission
    }

    /// Captures the app's frontmost normal on-screen window and its frame.
    public func captureFrontWindow(of app: ResolvedApp) async throws(ScreenReadingError)
        -> WindowCapture
    {
        guard
            CGPreflightScreenCaptureAccess()
                || (mayPromptForPermission && CGRequestScreenCaptureAccess())
        else {
            throw .screenRecordingNotAllowed
        }
        guard let processIdentifier = app.processIdentifier else {
            throw .appNotRunning(appName: app.identity.displayName)
        }
        let image: CGImage
        let windowFrame: CGRect
        do {
            (image, windowFrame) = try await Self.captureFrontWindow(
                of: processIdentifier, appName: app.identity.displayName)
        } catch let readingError as ScreenReadingError {
            throw readingError
        } catch {
            throw .captureFailed(reason: error.localizedDescription)
        }
        do {
            return WindowCapture(pngData: try Self.pngData(from: image), windowFrame: windowFrame)
        } catch {
            throw .captureFailed(reason: "Could not encode the screenshot.")
        }
    }

    /// The window's image and its frame in global screen points (top-left origin).
    private static func captureFrontWindow(of processIdentifier: pid_t, appName: String)
        async throws -> (image: CGImage, frame: CGRect)
    {
        let shareableContent = try await SCShareableContent.excludingDesktopWindows(
            true, onScreenWindowsOnly: true)
        let normalWindowLayer = 0
        guard
            let window = shareableContent.windows.first(where: { window in
                window.owningApplication?.processID == processIdentifier
                    && window.windowLayer == normalWindowLayer && window.isOnScreen
            })
        else {
            throw ScreenReadingError.noWindow(appName: appName)
        }
        let pixelSize = fittedPixelSize(forPointSize: window.frame.size, scale: captureScale)
        let configuration = SCStreamConfiguration()
        configuration.width = pixelSize.width
        configuration.height = pixelSize.height
        configuration.showsCursor = false
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: SCContentFilter(desktopIndependentWindow: window),
            configuration: configuration)
        return (image, window.frame)
    }

    /// The capture size: the window at Retina scale, shrunk so the longest side fits the limit.
    static func fittedPixelSize(forPointSize pointSize: CGSize, scale: CGFloat) -> PixelSize {
        let fullWidth = pointSize.width * scale
        let fullHeight = pointSize.height * scale
        let longestSide = max(fullWidth, fullHeight, 1)
        let shrinkFactor = min(1, CGFloat(maximumPixelDimension) / longestSide)
        return PixelSize(
            width: Int((fullWidth * shrinkFactor).rounded()),
            height: Int((fullHeight * shrinkFactor).rounded()))
    }

    /// Encodes `image` as PNG in memory.
    static func pngData(from image: CGImage) throws(ScreenReadingError) -> Data {
        let pngData = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                pngData, UTType.png.identifier as CFString, 1, nil)
        else {
            throw .captureFailed(reason: "Could not create a PNG encoder.")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw .captureFailed(reason: "Could not finish the PNG.")
        }
        return pngData as Data
    }
}
