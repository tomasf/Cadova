import Foundation

struct RotateExtrude: ExtrusionGeometry {
    let body: any Geometry2D
    let angle: Angle

    let moduleName = "rotate_extrude"
    var moduleParameters: CodeFragment.Parameters {
        ["angle": angle]
    }

    func boundary(for boundary2D: Boundary2D, facets: EnvironmentValues.Facets) -> Boundary3D {
        boundary2D.extruded(angle: angle, facets: facets)
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
