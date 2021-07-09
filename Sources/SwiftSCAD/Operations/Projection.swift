import Foundation

struct Projection: Geometry2D {
	let mode: Mode
	let body: Geometry3D

	func scadString(environment: Environment) -> String {
		switch mode {
		case .whole:
			return SCADCall(
				name: "projection",
				body: body
			)
			.scadString(environment: environment)

		case .slice (let z):
			return SCADCall(
				name: "projection",
				params: ["cut": true],
				body: body.translated(z: -z)
			)
			.scadString(environment: environment)
		}
	}

	enum Mode {
		case whole
		case slice (z: Double)
	}
}

public extension Geometry3D {
	func projection() -> Geometry2D {
		Projection(mode: .whole, body: self)
	}

	func projection(slicingAtZ z: Double) -> Geometry2D {
		Projection(mode: .slice(z: z), body: self)
	}
}
