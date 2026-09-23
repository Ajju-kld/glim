import GlimCore
import SwiftUI

/// Glim's orb: a sphere of flowing light. Colours drift through a mesh inside a liquid edge that
/// ripples with your voice, under a glossy highlight and a glowing rim, with a turning aura of
/// light behind it. It springs while Glim plans and acts, breathes while it waits, and rests
/// when done.
struct GlimOrbView: View {
    /// Tunable: the sphere's diameter as a fraction of the frame; the rest is room for the aura
    /// and for springing outward.
    private static let bodyFraction: CGFloat = 0.74
    /// Tunable: how far the aura spreads beyond the sphere, and how soft it is.
    private static let auraScale: CGFloat = 1.18
    private static let auraBlurFraction: CGFloat = 0.2
    /// Tunable: how fast the colours inside the sphere turn, relative to their flow.
    private static let swirlRate = 0.35

    let mood: OrbMood
    @State private var flowClock = OrbSpin()

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let flowTime = flowClock.angle(at: time, speed: OrbMotion.spinSpeed(for: mood))
            GeometryReader { geometry in
                let diameter = min(geometry.size.width, geometry.size.height) * Self.bodyFraction
                ZStack {
                    aura(diameter: diameter, flowTime: flowTime)
                    sphere(
                        diameter: diameter, time: time, flowTime: flowTime,
                        ripple: OrbMotion.ripple(for: mood))
                    if let symbolName {
                        Image(systemName: symbolName)
                            .font(.system(size: diameter * 0.36, weight: .heavy))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.35), radius: 2)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .scaleEffect(OrbMotion.scale(for: mood, at: time))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: symbolName)
        .accessibilityHidden(true)
    }

    // MARK: - Layers

    /// A blurred ring of the palette turning behind the sphere.
    private func aura(diameter: CGFloat, flowTime: Double) -> some View {
        Circle()
            .fill(
                AngularGradient(
                    colors: palette + [palette[0]], center: .center,
                    angle: .radians(flowTime * Self.swirlRate))
            )
            .frame(width: diameter * Self.auraScale, height: diameter * Self.auraScale)
            .blur(radius: diameter * Self.auraBlurFraction)
            .opacity(0.8)
    }

    private func sphere(diameter: CGFloat, time: Double, flowTime: Double, ripple: Double)
        -> some View
    {
        let edge = LiquidEdge(time: time, ripple: ripple)
        return ZStack {
            MeshGradient(
                width: 3, height: 3,
                points: LiquidOrbGeometry.meshPoints(time: flowTime, flow: 1),
                colors: meshColors
            )
            .rotationEffect(.radians(-flowTime * Self.swirlRate))
            .scaleEffect(1.3)
            // Depth: the sphere darkens toward its edge.
            RadialGradient(
                colors: [.clear, .black.opacity(0.45)], center: UnitPoint(x: 0.45, y: 0.4),
                startRadius: diameter * 0.15, endRadius: diameter * 0.62)
            // Gloss: a soft highlight up and to the left.
            Ellipse()
                .fill(.white.opacity(0.55))
                .frame(width: diameter * 0.42, height: diameter * 0.24)
                .blur(radius: diameter * 0.07)
                .offset(x: -diameter * 0.14, y: -diameter * 0.24)
        }
        .frame(width: diameter, height: diameter)
        .clipShape(edge)
        .overlay(
            edge.stroke(
                AngularGradient(
                    colors: [
                        .white.opacity(0.55), palette[1].opacity(0.5), .clear,
                        palette[2].opacity(0.4), .white.opacity(0.55),
                    ],
                    center: .center, angle: .radians(flowTime * Self.swirlRate * 2)),
                lineWidth: max(diameter * 0.014, 0.6)
            )
            .blendMode(.plusLighter)
        )
        .shadow(color: palette[0].opacity(0.6), radius: diameter * 0.12)
    }

    // MARK: - Style

    /// Four colours per mood, bright to deep.
    private var palette: [Color] {
        switch mood {
        case .listening:
            [
                Color(red: 0.35, green: 0.95, blue: 1.0), Color(red: 0.3, green: 0.45, blue: 1.0),
                Color(red: 0.75, green: 0.35, blue: 1.0), Color(red: 1.0, green: 0.45, blue: 0.8),
            ]
        case .thinking:
            [
                Color(red: 0.95, green: 0.4, blue: 1.0), Color(red: 0.45, green: 0.3, blue: 1.0),
                Color(red: 1.0, green: 0.5, blue: 0.55), Color(red: 0.3, green: 0.75, blue: 1.0),
            ]
        case .acting:
            [
                Color(red: 0.4, green: 1.0, blue: 0.75), Color(red: 0.1, green: 0.75, blue: 0.85),
                Color(red: 0.35, green: 0.55, blue: 1.0), Color(red: 0.7, green: 1.0, blue: 0.5),
            ]
        case .waiting:
            [
                Color(red: 1.0, green: 0.8, blue: 0.3), Color(red: 1.0, green: 0.5, blue: 0.25),
                Color(red: 1.0, green: 0.4, blue: 0.55), Color(red: 1.0, green: 0.9, blue: 0.6),
            ]
        case .done:
            [
                Color(red: 0.45, green: 1.0, blue: 0.6), Color(red: 0.15, green: 0.75, blue: 0.55),
                Color(red: 0.4, green: 0.9, blue: 0.9), Color(red: 0.8, green: 1.0, blue: 0.7),
            ]
        case .alert:
            [
                Color(red: 1.0, green: 0.35, blue: 0.35), Color(red: 0.8, green: 0.1, blue: 0.25),
                Color(red: 1.0, green: 0.55, blue: 0.3), Color(red: 1.0, green: 0.3, blue: 0.5),
            ]
        }
    }

    /// The palette spread over the 3×3 mesh so neighbouring points differ.
    private var meshColors: [Color] {
        let colors = palette
        return [0, 1, 2, 3, 0, 1, 2, 3, 0].map { colors[$0] }
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

/// The sphere's rippling outline, from ``LiquidOrbGeometry/edgeRadius(at:time:ripple:)``.
private struct LiquidEdge: Shape {
    /// Tunable: points around the outline; enough for a smooth curve at any orb size.
    private static let outlinePointCount = 96

    let time: Double
    let ripple: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let fullRadius = min(rect.width, rect.height) / 2
        var path = Path()
        for pointIndex in 0...Self.outlinePointCount {
            let angle = Double(pointIndex) / Double(Self.outlinePointCount) * 2 * .pi
            let radius =
                fullRadius
                * LiquidOrbGeometry.edgeRadius(at: angle, time: time, ripple: ripple)
            let point = CGPoint(
                x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            if pointIndex == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

/// Accumulates the orb's flow, so a change of speed never makes the colours jump.
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
