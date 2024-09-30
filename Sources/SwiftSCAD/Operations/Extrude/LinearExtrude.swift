import Foundation

struct LinearExtrude: Geometry3D {
    let body: any Geometry2D

    let height: Double
    let twist: Angle?
    let scale: Vector2D
    let convexity: Int

    func invocation(in environment: Environment) -> Invocation {
        .init(name: "linear_extrude", parameters: [
            "height": height,
            "twist": twist.map { -$0 } ?? 0°,
            "scale": scale,
            "convexity": convexity
        ], body: [body.invocation(in: environment)])
    }

    func boundary(in environment: Environment) -> Bounds {
        body.boundary(in: environment)
            .extruded(height: height, twist: twist ?? 0°, topScale: scale, facets: environment.facets)
    }

    func anchors(in environment: Environment) -> [Anchor : AffineTransform3D] {
        body.anchors(in: environment)
    }

    func elements(in environment: Environment) -> [ObjectIdentifier : any ResultElement] {
        body.elements(in: environment)
    }
}

public extension Geometry2D {
    /// Extrude two-dimensional geometry in the Z axis, creating three-dimensional geometry
    /// - Parameters:
    ///   - height: The height of the resulting geometry, in the Z axis
    ///   - twist: The rotation of the top surface, gradually rotating the geometry around the Z axis, resulting in a twisted shape. Defaults to no twist. Note that the twist direction follows the right-hand rule, which is the opposite of OpenSCAD's behavior.
    ///   - scale: The final scale at the top of the extruded shape. The geometry is scaled linearly from 1.0 at the bottom.
    ///   - convexity: The maximum number of surfaces a straight line can intersect the result. This helps OpenSCAD preview the geometry correctly, but has no effect on final rendering.
    func extruded(height: Double, twist: Angle? = nil, scale: Vector2D = [1, 1], convexity: Int = 2) -> any Geometry3D {
        LinearExtrude(body: self, height: height, twist: twist, scale: scale, convexity: convexity)
    }
}
