import Foundation

struct RotateExtrude: Geometry3D {
    let body: any Geometry2D
    let angle: Angle
    let convexity: Int

    func invocation(in environment: Environment) -> Invocation {
        .init(name: "rotate_extrude", parameters: [
            "angle": angle,
            "convexity": convexity
        ], body: [body.invocation(in: environment)])
    }

    func boundary(in environment: Environment) -> Bounds {
        body.boundary(in: environment)
            .extruded(angle: angle, facets: environment.facets)
    }

    func anchors(in environment: Environment) -> [Anchor : AffineTransform3D] {
        body.anchors(in: environment)
    }

    func elements(in environment: Environment) -> [ObjectIdentifier : any ResultElement] {
        body.elements(in: environment)
    }
}

public extension Geometry2D {
    /// Extrude two-dimensional geometry around the Z axis, creating three-dimensional geometry
    /// - Parameters:
    ///   - angles: The angle range in which to extrude. The resulting shape is formed around the Z axis in this range.
    ///   - convexity: The maximum number of surfaces a straight line can intersect the result. This helps OpenSCAD preview the geometry correctly, but has no effect on final rendering.
    func extruded(angles: Range<Angle> = 0°..<360°, convexity: Int = 2) -> any Geometry3D {
        RotateExtrude(body: self, angle: angles.upperBound - angles.lowerBound, convexity: convexity)
            .rotated(z: angles.lowerBound)
    }
}
