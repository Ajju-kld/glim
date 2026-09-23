import GlimCore
import SwiftUI

/// The glowing torus-ring orb. Its rings flow around the torus; it swells with your voice while
/// listening, springs while Glim plans and acts, and rests when done.
struct TorusOrbView: View {
    /// Tunable: the orb's radius as a fraction of its frame, leaving room to spring outward.
    private static let fillFraction: CGFloat = 0.8
    /// Tunable: blur of the soft glow drawn under the crisp rings.
    private static let glowBlurRadius: CGFloat = 2.5
    /// Tunable: how strong that glow is.
    private static let glowOpacity = 0.7

    let mood: OrbMood
    @State private var spin = OrbSpin()

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let rotation = spin.angle(at: time, speed: OrbMotion.spinSpeed(for: mood))
            let rings = TorusGeometry.rings(
                rotation: rotation, tubeThickness: OrbMotion.tubeThickness(for: mood))
            ZStack {
                Canvas { context, size in
                    drawCoreLight(in: context, size: size)
                }
                Canvas { context, size in
                    drawRings(rings, in: context, size: size, lineWidthScale: 2)
                }
                .blur(radius: Self.glowBlurRadius)
                .opacity(Self.glowOpacity)
                .blendMode(.plusLighter)
                Canvas { context, size in
                    drawRings(rings, in: context, size: size, lineWidthScale: 1)
                }
                if let symbolName {
                    GeometryReader { geometry in
                        Image(systemName: symbolName)
                            .font(
                                .system(
                                    size: min(geometry.size.width, geometry.size.height) * 0.3,
                                    weight: .heavy)
                            )
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .scaleEffect(OrbMotion.scale(for: mood, at: time))
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: symbolName)
        .accessibilityHidden(true)
    }

    // MARK: - Drawing

    private func drawRings(
        _ rings: [TorusRing], in context: GraphicsContext, size: CGSize, lineWidthScale: CGFloat
    ) {
        let radius = min(size.width, size.height) / 2 * Self.fillFraction
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let baseLineWidth = max(radius / 20, 0.7)
        for ring in rings {
            var path = Path()
            path.addLines(
                ring.points.map { point in
                    CGPoint(x: center.x + point.x * radius, y: center.y + point.y * radius)
                })
            path.closeSubpath()
            var ringContext = context
            ringContext.opacity = 0.1 + 0.9 * ring.depth
            let color = palette.far.mix(with: palette.near, by: ring.depth)
            ringContext.stroke(
                path, with: .color(color),
                lineWidth: baseLineWidth * lineWidthScale * (0.6 + 0.8 * ring.depth))
        }
    }

    /// A soft halo around the ring, dark in the middle, so the orb glows without filling in.
    private func drawCoreLight(in context: GraphicsContext, size: CGSize) {
        let radius = min(size.width, size.height) / 2
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let lightRect = CGRect(
            x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(
            Path(ellipseIn: lightRect),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: .clear, location: 0.3),
                    .init(color: palette.far.opacity(0.35), location: 0.7),
                    .init(color: .clear, location: 1),
                ]),
                center: center, startRadius: 0, endRadius: radius))
    }

    // MARK: - Style

    private var palette: (near: Color, far: Color) {
        switch mood {
        case .listening:
            (Color(red: 0.45, green: 0.95, blue: 1.0), Color(red: 0.45, green: 0.3, blue: 1.0))
        case .thinking:
            (Color(red: 0.95, green: 0.5, blue: 1.0), Color(red: 0.35, green: 0.3, blue: 1.0))
        case .acting:
            (Color(red: 0.5, green: 1.0, blue: 0.7), Color(red: 0.1, green: 0.6, blue: 0.9))
        case .waiting:
            (Color(red: 1.0, green: 0.8, blue: 0.35), Color(red: 1.0, green: 0.4, blue: 0.2))
        case .done:
            (Color(red: 0.55, green: 1.0, blue: 0.65), Color(red: 0.15, green: 0.7, blue: 0.5))
        case .alert:
            (Color(red: 1.0, green: 0.45, blue: 0.4), Color(red: 0.75, green: 0.1, blue: 0.2))
        }
    }

    private var symbolName: String? {
        switch mood {
        case .done: "checkmark"
        case .alert: "exclamationmark"
        case .waiting: "hand.raised.fill"
        case .listening, .thinking, .acting: nil
        }
    }
}

/// Accumulates the orb's turn, so a change of spin speed never makes the rings jump.
@MainActor
final class OrbSpin {
    private var angle = 0.0
    private var previousTime: TimeInterval?

    func angle(at time: TimeInterval, speed: Double) -> Double {
        if let previousTime {
            angle += (time - previousTime) * speed
        }
        previousTime = time
        return angle
    }
}
