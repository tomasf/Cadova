import Foundation

struct Transform: Geometry3D {
	let transform: AffineTransform
	let body: Geometry3D

	func scadString(environment: Environment) -> String {
		SCADCall(
			name: "multmatrix",
			params: ["m": transform],
			body: body
		)
		.scadString(environment: environment)
	}
}

public extension Geometry3D {
	func transformed(_ transform: AffineTransform) -> Geometry3D {
		Transform(transform: transform, body: self)
	}

	func sheared(_ axis: Axis3D, along otherAxis: Axis3D, factor: Double) -> Geometry3D {
		transformed(.shearing(axis, along: otherAxis, factor: factor))
	}

	func sheared(_ axis: Axis3D, along otherAxis: Axis3D, angle: Angle) -> Geometry3D {
		transformed(.shearing(axis, along: otherAxis, angle: angle))
	}
}
