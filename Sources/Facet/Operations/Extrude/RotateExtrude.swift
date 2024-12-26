import Foundation
import Manifold

struct RotateExtrude: ExtrusionGeometry {
    let body: any Geometry2D
    let angle: Angle

    func extrude(_ child: CrossSection, in environment: EnvironmentValues) -> Mesh {
        let bounds = child.bounds
        let radius = bounds.min.x < 0 && bounds.max.x <= 0 ? -bounds.min.x : bounds.max.x
        return child.revolve(
            degrees: angle.degrees,
            circularSegments: environment.facets.facetCount(circleRadius: radius)
        )
    }
}

public extension Geometry2D {
    /// Extrude two-dimensional geometry around the Z axis, creating three-dimensional geometry
    /// - Parameters:
    ///   - angles: The angle range in which to extrude. The resulting shape is formed around the Z axis in this range.
    func extruded(angles: Range<Angle> = 0°..<360°) -> any Geometry3D {
        RotateExtrude(body: self, angle: angles.upperBound - angles.lowerBound)
            .rotated(z: angles.lowerBound)
    }
}
