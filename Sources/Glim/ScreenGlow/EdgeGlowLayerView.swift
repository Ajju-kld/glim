import AppKit
import GlimCore
import QuartzCore
import SwiftUI

/// Light bleeding in from the edges: a turning ring of the theme's colours, brighter while you
/// speak and pulsing while Glim thinks.
///
/// Drawn for speed. The ring's shape (three soft bands along the edge) is painted once into a
/// mask image; the colours are a conic gradient that Core Animation turns, and the pulse is a
/// Core Animation opacity animation. The app's main thread only sets new colours or brightness
/// when the ``EdgeGlowAppearance`` changes, so the glow never competes with the notch orb for
/// frames.
final class EdgeGlowLayerView: NSView {
    /// Tunable: the soft outer haze, the brighter band and the crisp edge line, in points, and
    /// how bright each is.
    private static let hazeWidth: CGFloat = 60
    private static let hazeBlur: CGFloat = 40
    private static let hazeAlpha: CGFloat = 0.8
    private static let bandWidth: CGFloat = 18
    private static let bandBlur: CGFloat = 10
    private static let edgeLineWidth: CGFloat = 3
    /// Tunable: how quickly brightness follows the voice.
    private static let brightnessChangeSeconds = 0.18
    private static let rotationAnimationKey = "turn"
    private static let pulseAnimationKey = "pulse"

    private let cornerRadius: CGFloat
    private let widthScale: CGFloat
    private let gradientLayer = CAGradientLayer()
    private let maskLayer = CALayer()
    private var appliedAppearance: EdgeGlowAppearance?
    private var maskSize = CGSize.zero

    /// Creates the view.
    ///
    /// - Parameters:
    ///   - cornerRadius: The rounding of the edge the glow follows.
    ///   - widthScale: Scales the glow's widths, so a small preview looks like the full screen.
    init(cornerRadius: CGFloat, widthScale: CGFloat = 1) {
        self.cornerRadius = cornerRadius
        self.widthScale = widthScale
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = true
        gradientLayer.type = .conic
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 0)
        layer?.addSublayer(gradientLayer)
        layer?.mask = maskLayer
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("EdgeGlowLayerView is built in code only.")
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // The gradient covers the whole view at every angle while it turns.
        let diagonal = hypot(bounds.width, bounds.height)
        gradientLayer.bounds = CGRect(x: 0, y: 0, width: diagonal, height: diagonal)
        gradientLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        maskLayer.frame = bounds
        CATransaction.commit()
        if bounds.size != maskSize, bounds.width > 0, bounds.height > 0 {
            maskSize = bounds.size
            maskLayer.contents = Self.ringMask(
                size: bounds.size, scale: window?.backingScaleFactor ?? 2,
                cornerRadius: cornerRadius, widthScale: widthScale)
        }
        startTurning()
    }

    /// Shows `appearance`; does nothing when it is what is already shown.
    func apply(_ appearance: EdgeGlowAppearance) {
        guard appearance != appliedAppearance else {
            return
        }
        let previous = appliedAppearance
        appliedAppearance = appearance
        if previous?.colours != appearance.colours {
            let colours = appearance.colours.map { NSColor(Color($0)).cgColor }
            CATransaction.begin()
            CATransaction.setAnimationDuration(Self.brightnessChangeSeconds)
            gradientLayer.colors = colours + [colours.first ?? NSColor.white.cgColor]
            CATransaction.commit()
        }
        CATransaction.begin()
        CATransaction.setAnimationDuration(Self.brightnessChangeSeconds)
        gradientLayer.opacity = Float(appearance.brightness)
        CATransaction.commit()
        if appearance.pulses != previous?.pulses {
            appearance.pulses ? startPulsing(from: appearance.brightness) : stopPulsing()
        }
    }

    private func startTurning() {
        guard gradientLayer.animation(forKey: Self.rotationAnimationKey) == nil else {
            return
        }
        let turn = CABasicAnimation(keyPath: "transform.rotation.z")
        turn.fromValue = 0
        turn.toValue = -2 * Double.pi
        turn.duration = EdgeGlowMotion.secondsPerTurn
        turn.repeatCount = .infinity
        gradientLayer.add(turn, forKey: Self.rotationAnimationKey)
    }

    private func startPulsing(from brightness: Double) {
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = brightness
        pulse.toValue = min(brightness + EdgeGlowMotion.pulseDepth, 1)
        pulse.duration = EdgeGlowMotion.pulseSeconds / 2
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        gradientLayer.add(pulse, forKey: Self.pulseAnimationKey)
    }

    private func stopPulsing() {
        gradientLayer.removeAnimation(forKey: Self.pulseAnimationKey)
    }

    /// The ring's shape as an alpha mask: a wide soft haze, a brighter band and a crisp line
    /// along the edge. Painted once per size; blur comes from shadows, which are cheap to draw.
    private static func ringMask(
        size: CGSize, scale: CGFloat, cornerRadius: CGFloat, widthScale: CGFloat
    ) -> CGImage? {
        let pixelWidth = Int((size.width * scale).rounded())
        let pixelHeight = Int((size.height * scale).rounded())
        guard
            let context = CGContext(
                data: nil, width: pixelWidth, height: pixelHeight, bitsPerComponent: 8,
                bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else {
            return nil
        }
        context.scaleBy(x: scale, y: scale)
        let edgePath = CGPath(
            roundedRect: CGRect(origin: .zero, size: size), cornerWidth: cornerRadius,
            cornerHeight: cornerRadius, transform: nil)
        let bands: [(width: CGFloat, blur: CGFloat, alpha: CGFloat)] = [
            (hazeWidth, hazeBlur, hazeAlpha), (bandWidth, bandBlur, 1), (edgeLineWidth, 0, 1),
        ]
        for band in bands {
            context.saveGState()
            let bandColour = CGColor(gray: 1, alpha: band.alpha)
            context.setShadow(
                offset: .zero, blur: band.blur * widthScale * scale, color: bandColour)
            context.setStrokeColor(bandColour)
            context.setLineWidth(band.width * widthScale)
            context.addPath(edgePath)
            context.strokePath()
            context.restoreGState()
        }
        return context.makeImage()
    }
}

/// The glow for SwiftUI, used by the Screen Glow page's preview.
struct EdgeGlowPreview: NSViewRepresentable {
    let appearance: EdgeGlowAppearance
    let cornerRadius: CGFloat
    let widthScale: CGFloat

    func makeNSView(context: Context) -> EdgeGlowLayerView {
        EdgeGlowLayerView(cornerRadius: cornerRadius, widthScale: widthScale)
    }

    func updateNSView(_ glowView: EdgeGlowLayerView, context: Context) {
        glowView.apply(appearance)
    }
}
