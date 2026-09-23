import Foundation

/// The notch orb's shape and colour flow: a sphere of light whose edge ripples like liquid and
/// whose colours drift through a 3×3 mesh. Pure math, so the animation is testable.
public enum LiquidOrbGeometry {
    /// Business rule: at full ripple the edge dips at most this far in (a fraction of the radius),
    /// so the orb never looks broken.
    public static let maximumRippleDepth = 0.12

    /// Ripple waves: how many bumps go round the edge, how fast each travels, and its share of
    /// the depth. Several waves at different speeds make the edge look liquid, not mechanical.
    private static let rippleWaves: [(bumps: Double, speed: Double, share: Double)] = [
        (3, 1.3, 0.5), (5, -2.1, 0.3), (7, 3.4, 0.2),
    ]
    /// Tunable: how far the mesh's inner points drift from their places (unit square).
    private static let meshDrift = 0.22

    /// The edge's distance from the centre at `angle`, as a fraction of the full radius.
    ///
    /// - Parameters:
    ///   - angle: Around the orb, in radians.
    ///   - time: Seconds, for the ripple's movement.
    ///   - ripple: How lively the edge is, 0 (a perfect circle) to 1 (full ripple).
    /// - Returns: The radius there, from 1 − ``maximumRippleDepth`` up to 1.
    public static func edgeRadius(at angle: Double, time: Double, ripple: Double) -> Double {
        let strength = min(max(ripple, 0), 1)
        guard strength > 0 else {
            return 1
        }
        let wave = rippleWaves.reduce(0.0) { total, wave in
            total + wave.share * (sin(wave.bumps * angle + wave.speed * time) + 1) / 2
        }
        return 1 - maximumRippleDepth * strength * wave
    }

    /// The nine points of the colour mesh at `time`, row by row. Corners and edges stay on the
    /// square's border; the inner point and the edge midpoints drift, so the colours swirl.
    ///
    /// - Parameters:
    ///   - time: Seconds of accumulated flow.
    ///   - flow: How far the points drift, 0 (still) to 1.
    /// - Returns: Nine points in the unit square, for a 3×3 mesh gradient.
    public static func meshPoints(time: Double, flow: Double) -> [SIMD2<Float>] {
        let drift = meshDrift * min(max(flow, 0), 1)
        func wander(_ phase: Double, _ speed: Double) -> Double {
            drift * sin(time * speed + phase)
        }
        let points: [(Double, Double)] = [
            (0, 0), (0.5 + wander(0, 0.9), 0), (1, 0),
            (0, 0.5 + wander(1.7, 1.1)), (0.5 + wander(2.3, 1.3), 0.5 + wander(4.1, 0.7)),
            (1, 0.5 + wander(3.1, 0.8)),
            (0, 1), (0.5 + wander(5.2, 1.2), 1), (1, 1),
        ]
        return points.map { SIMD2(Float($0.0), Float($0.1)) }
    }
}
