import CoreGraphics
import Foundation
import Testing

@testable import GlimCore

struct WindowScreenshotterTests {
    func makeImage(width: Int, height: Int) throws -> CGImage {
        let context = try #require(
            CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try #require(context.makeImage())
    }

    @Test func imagesEncodeAsPNG() throws {
        let pngData = try WindowScreenshotter.pngData(from: makeImage(width: 8, height: 4))

        #expect(pngData.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
    }

    @Test func largeWindowsAreScaledDownKeepingTheirShape() {
        let fittedSize = WindowScreenshotter.fittedPixelSize(
            forPointSize: CGSize(width: 1_600, height: 900), scale: 2)

        #expect(fittedSize.width == WindowScreenshotter.maximumPixelDimension)
        #expect(fittedSize.height == 720)
    }

    @Test func smallWindowsKeepTheirPixelSize() {
        let fittedSize = WindowScreenshotter.fittedPixelSize(
            forPointSize: CGSize(width: 300, height: 200), scale: 2)

        #expect(fittedSize == PixelSize(width: 600, height: 400))
    }

    @Test(
        .enabled(if: !CGPreflightScreenCaptureAccess(), "Only when Screen Recording is not granted")
    )
    func missingPermissionIsReportedWithoutPrompting() async {
        let app = ResolvedApp(
            identity: AppIdentity(
                bundleIdentifier: "com.apple.finder", displayName: "Finder", hasValidSignature: true
            ),
            bundleURL: nil, processIdentifier: 1)

        await #expect(throws: ScreenReadingError.screenRecordingNotAllowed) {
            _ = try await WindowScreenshotter(mayPromptForPermission: false).capturePNG(of: app)
        }
    }
}
