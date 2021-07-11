import Foundation

struct ConvexHull3D: CoreGeometry3D {
	let body: Geometry3D

	func call(in environment: Environment) -> SCADCall {
		SCADCall(name: "hull", body: body)
	}
}

public extension Geometry3D {
	func convexHull() -> Geometry3D {
		ConvexHull3D(body: self)
	}
}


struct ConvexHull2D: CoreGeometry2D {
	let body: Geometry2D

	func call(in environment: Environment) -> SCADCall {
		SCADCall(name: "hull", body: body)
	}
}

public extension Geometry2D {
	func convexHull() -> Geometry2D {
		ConvexHull2D(body: self)
	}
}
