import Foundation

struct Translate3D: Geometry3D {
	let distance: Vector3D
	let body: Geometry3D

	func scadString(environment: Environment) -> String {
		SCADCall(
			name: "translate",
			params: ["v": distance],
			body: body
		)
		.scadString(environment: environment)
	}
}

public extension Geometry3D {
	func translated(_ distance: Vector3D) -> Geometry3D {
		Translate3D(distance: distance, body: self)
	}

	func translated(x: Double = 0, y: Double = 0, z: Double = 0) -> Geometry3D {
		Translate3D(distance: [x, y, z], body: self)
	}
}


struct Translate2D: Geometry2D {
	let distance: Vector2D
	let body: Geometry2D

	func scadString(environment: Environment) -> String {
		SCADCall(
			name: "translate",
			params: ["v": distance],
			body: body
		)
		.scadString(environment: environment)
	}
}

public extension Geometry2D {
	func translated(_ distance: Vector2D) -> Geometry2D {
		Translate2D(distance: distance, body: self)
	}

	func translated(x: Double = 0, y: Double = 0) -> Geometry2D {
		Translate2D(distance: [x, y], body: self)
	}
}
