import Foundation

struct LinearExtrude: Geometry3D {
    let body: any Geometry2D

    let height: Double
    let twist: Angle
    let slices: Int?
    let segments: Int?
    let scale: Vector2D
    let convexity: Int

    func output(in environment: Environment) -> Output {
        return GeometryOutput<Vector3D>(
            invocation: .init(name: "linear_extrude", parameters: [
                "height": height,
                "twist": twist,
                "slices": slices,
                "segments": segments,
                "scale": scale,
                "convexity": convexity
            ]),
            body: body,
            environment: environment,
            boundaryMapping: { $0.extruded(height: height, topScale: scale) }
        )
    }
}

public extension Geometry2D {
    /// Extrude two-dimensional geometry in the Z axis, creating three-dimensional geometry
    /// - Parameters:
    ///   - height: The height of the resulting geometry, in the Z axis
    ///   - twist: The rotation of the top surface, gradually rotating the geometry around the Z axis, resulting in a twisted shape.
    ///   - slices: The number of intermediary layers along the Z axis.
    ///   - segements: The number of segments to use for the source shape
    ///   - scale: The final scale at the top of the extruded shape. The rest of the geometry is scaled linearly from 1.0 at the bottom.
    ///   - convexity: The maximum number of surfaces a straight line can intersect the result. This helps OpenSCAD preview the geometry correctly, but has no effect on final rendering.
    func extruded(height: Double, twist: Angle = 0°, slices: Int? = nil, segments: Int? = nil, scale: Vector2D = [1, 1], convexity: Int = 2) -> any Geometry3D {
        LinearExtrude(body: self, height: height, twist: twist, slices: slices, segments: segments, scale: scale, convexity: convexity)
    }
}
