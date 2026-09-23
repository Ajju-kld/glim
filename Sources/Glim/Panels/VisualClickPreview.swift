import AppKit
import GlimCore
import SwiftUI

/// The screenshot a click was found on, with a ring on the spot Glim will click, so the person
/// checks the place itself rather than a label Glim never read.
struct VisualClickPreview: View {
    /// Tunable: the ring's diameter on the preview, in points.
    private static let markerDiameter: CGFloat = 28
    /// Tunable: the ring's line width, thick enough to see on any background.
    private static let markerLineWidth: CGFloat = 3
    /// Tunable: the ring's tinted fill, light enough to see what is under it.
    private static let markerFillOpacity = 0.2
    /// Tunable: the tallest the preview may be, so the buttons stay on screen.
    private static let maximumPreviewHeight: CGFloat = 260

    let visualClick: VisualClick

    var body: some View {
        if let screenshot = NSImage(data: visualClick.screenshotPNG) {
            Image(nsImage: screenshot)
                .resizable()
                .scaledToFit()
                .overlay {
                    GeometryReader { proxy in
                        Circle()
                            .stroke(.red, lineWidth: Self.markerLineWidth)
                            .background(Circle().fill(.red.opacity(Self.markerFillOpacity)))
                            .frame(width: Self.markerDiameter, height: Self.markerDiameter)
                            .position(markerPosition(in: proxy.size))
                    }
                }
                .clipShape(.rect(cornerRadius: PanelStyle.cornerRadius))
                .frame(maxHeight: Self.maximumPreviewHeight)
                .accessibilityLabel("Screenshot with the spot Glim will click marked")
        } else {
            Label("The screenshot could not be shown.", systemImage: "photo")
                .foregroundStyle(.secondary)
        }
    }

    private func markerPosition(in previewSize: CGSize) -> CGPoint {
        let gridSize = CGFloat(VisualTarget.gridSize)
        return CGPoint(
            x: previewSize.width * CGFloat(visualClick.target.gridX) / gridSize,
            y: previewSize.height * CGFloat(visualClick.target.gridY) / gridSize)
    }
}
