import Foundation

struct Projection: CoreGeometry2D {
	let mode: Mode
	let body: Geometry3D

	func call(in environment: Environment) -> SCADCall {
		switch mode {
		case .whole:
			return SCADCall(
				name: "projection",
				body: body
			)

		case .slice (let z):
			return SCADCall(
				name: "projection",
				params: ["cut": true],
				body: body.translated(z: -z)
			)
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
