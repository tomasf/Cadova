import Foundation

struct Intersection3D: CoreGeometry3D {
	let children: [Geometry3D]

	func call(in environment: Environment) -> SCADCall {
		SCADCall(name: "intersection", body: GeometrySequence(children: children))
	}
}

public extension Geometry3D {
	func intersection(@UnionBuilder with other: () -> Geometry3D) -> Geometry3D {
		Intersection3D(children: [self, other()])
	}
}


struct Intersection2D: CoreGeometry2D {
	let children: [Geometry2D]

	func call(in environment: Environment) -> SCADCall {
		SCADCall(name: "intersection", body: GeometrySequence(children: children))
	}
}

public extension Geometry2D {
	func intersection(@UnionBuilder with other: () -> Geometry2D) -> Geometry2D {
		Intersection2D(children: [self, other()])
	}
}
