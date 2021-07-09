import Foundation

struct Difference3D: Geometry3D {
	let positive: Geometry3D
	let negative: Geometry3D

	init(positive: Geometry3D, negative: Geometry3D) {
		self.positive = positive
		self.negative = negative
	}

	func scadString(environment: Environment) -> String {
		SCADCall(name: "difference", body: GeometrySequence(children: [positive, negative]))
			.scadString(environment: environment)
	}
}

public extension Geometry3D {
	func subtracting(@UnionBuilder _ negative: () -> Geometry3D) -> Geometry3D {
		Difference3D(positive: self, negative: negative())
	}
}


struct Difference2D: Geometry2D {
	let positive: Geometry2D
	let negative: Geometry2D

	init(positive: Geometry2D, negative: Geometry2D) {
		self.positive = positive
		self.negative = negative
	}

	func scadString(environment: Environment) -> String {
		SCADCall(name: "difference", body: GeometrySequence(children: [positive, negative]))
			.scadString(environment: environment)
	}
}

public extension Geometry2D {
	func subtracting(@UnionBuilder _ negative: () -> Geometry2D) -> Geometry2D {
		Difference2D(positive: self, negative: negative())
	}
}
