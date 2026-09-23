import CoreGraphics
import Foundation

/// One tube ring of the torus, projected to 2D.
public struct TorusRing: Sendable, Equatable {
    /// The ring's outline in unit space: centered on 0, inside the unit circle, y pointing down.
    public let points: [CGPoint]
    /// How near the ring is to the viewer: 0 at the back, 1 at the front.
    public let depth: Double
}

/// The notch orb's shape: a torus seen at a tilt, drawn as rings that circle the torus's axis.
/// As `rotation` grows the rings roll through the tube, like a smoke ring turning over.
public enum TorusGeometry {
    /// Tunable: rings drawn around the torus.
    public static let ringCount = 12
    /// Tunable: points per ring outline.
    public static let pointsPerRing = 48
    /// Tunable: camera tilt in radians — 0 looks straight down, π/2 looks edge-on.
    public static let cameraTilt = 0.72

    /// The torus's rings for one moment of the animation.
    ///
    /// - Parameters:
    ///   - rotation: How far the rings have rolled through the tube, in radians.
    ///   - tubeThickness: The tube's radius as a fraction of the whole orb's radius.
    /// - Returns: The rings, sorted back to front so nearer rings are drawn over farther ones.
    public static func rings(rotation: Double, tubeThickness: Double) -> [TorusRing] {
        let tubeRadius = min(max(tubeThickness, 0.05), 0.45)
        let centerRadius = 1 - tubeRadius
        let tiltCosine = cos(cameraTilt)
        let tiltSine = sin(cameraTilt)
        let rings = (0..<ringCount).map { ringIndex in
            let aroundTube = rotation + 2 * .pi * Double(ringIndex) / Double(ringCount)
            let ringRadius = centerRadius + tubeRadius * cos(aroundTube)
            let height = tubeRadius * sin(aroundTube)
            let points = (0..<pointsPerRing).map { pointIndex in
                let aroundAxis = 2 * .pi * Double(pointIndex) / Double(pointsPerRing)
                let x = ringRadius * cos(aroundAxis)
                let y = ringRadius * sin(aroundAxis)
                return CGPoint(x: x, y: y * tiltCosine - height * tiltSine)
            }
            // The top of the tube faces the tilted camera; the underside is farthest away.
            return TorusRing(points: points, depth: (sin(aroundTube) + 1) / 2)
        }
        return rings.sorted { $0.depth < $1.depth }
    }
}
