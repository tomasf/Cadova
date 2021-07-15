import Foundation

struct LinearExtrude: CoreGeometry3D {
	let height: Double
	let twist: Angle
	let slices: Int?
	let scale: Vector2D

	let convexity: Int
	let body: Geometry2D

	func call(in environment: Environment) -> SCADCall {
		return SCADCall(
			name: "linear_extrude",
			params: [
				"height": height,
				"twist": twist,
				"slices": slices,
				"scale": scale,
				"convexity": convexity
			],
			body: body
		)
	}
}

struct RotateExtrude: CoreGeometry3D {
	let angle: Angle
	let convexity: Int
	let body: Geometry2D

	func call(in environment: Environment) -> SCADCall {
		return SCADCall(
			name: "rotate_extrude",
			params: [
				"angle": angle,
				"convexity": convexity
			],
			body: body
		)
	}
}

public extension Geometry2D {
    /// Extrude two-dimensional geometry in the Z axis, creating three-dimensional geometry
    /// - Parameters:
    ///   - height: The height of the resulting geometry, in the Z axis
    ///   - twist: The rotation of the top surface, gradually rotating the geometry around the Z axis, resulting in a twisted shape.
    ///   - slices: The number of intermediary layers along the Z axis.
    ///   - scale: The final scale at the top of the extruded shape. The rest of the geometry is scaled linearly from 1.0 at the bottom.
    ///   - convexity: The maximum number of surfaces a straight line can intersect the result. This helps OpenSCAD preview the geometry correctly, but has no effect on final rendering.
	func extruded(height: Double, twist: Angle = 0°, slices: Int? = nil, scale: Vector2D = [1, 1], convexity: Int = 2) -> Geometry3D {
		LinearExtrude(height: height, twist: twist, slices: slices, scale: scale, convexity: convexity, body: self)
	}

    /// Extrude two-dimensional geometry around the Z axis, creating three-dimensional geometry
    /// - Parameters:
    ///   - angles: The angle range in which to extrude. The resulting shape is formed around the Z axis in this range.
    ///   - convexity: The maximum number of surfaces a straight line can intersect the result. This helps OpenSCAD preview the geometry correctly, but has no effect on final rendering.
	func extruded(angles: Range<Angle>, convexity: Int = 2) -> Geometry3D {
        RotateExtrude(angle: angles.upperBound - angles.lowerBound, convexity: convexity, body: self)
            .rotated(z: angles.lowerBound)
	}
}
