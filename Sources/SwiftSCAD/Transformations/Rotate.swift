import Foundation

struct Rotate3D: Geometry3D {
	let x: Angle
	let y: Angle
	let z: Angle
	let body: Geometry3D

	func scadString(environment: Environment) -> String {
		return SCADCall(
			name: "rotate",
			params: ["a": [x, y, z]],
			body: body
		)
		.scadString(environment: environment)
	}
}

public extension Geometry3D {
	func rotated(_ angles: [Angle]) -> Geometry3D {
		precondition(angles.count == 3, "Rotate3D needs three angles")
		return Rotate3D(x: angles[0], y: angles[1], z: angles[2], body: self)
	}

	func rotated(x: Angle = 0°, y: Angle = 0°, z: Angle = 0°) -> Geometry3D {
		rotated([x, y, z])
	}

	func rotated(angle: Angle, axis: Axis3D) -> Geometry3D {
		var angles = [0°, 0°, 0°]
		angles[axis.rawValue] = angle
		return rotated(angles)
	}
}


struct Rotate2D: Geometry2D {
	let angle: Angle
	let body: Geometry2D

	func scadString(environment: Environment) -> String {
		return SCADCall(
			name: "rotate",
			params: ["a": angle],
			body: body
		)
		.scadString(environment: environment)
	}
}

public extension Geometry2D {
	func rotated(_ angle: Angle) -> Geometry2D {
		Rotate2D(angle: angle, body: self)
	}
}
