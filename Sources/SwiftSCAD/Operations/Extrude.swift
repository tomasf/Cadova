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
	func extruded(height: Double, twist: Angle = 0°, slices: Int? = nil, scale: Vector2D = [1, 1], convexity: Int = 2) -> Geometry3D {
		LinearExtrude(height: height, twist: twist, slices: slices, scale: scale, convexity: convexity, body: self)
	}

	func extruded(angle: Angle, convexity: Int = 2) -> Geometry3D {
		RotateExtrude(angle: angle, convexity: convexity, body: self)
	}
}
