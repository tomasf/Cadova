import Foundation

struct Intersection3D: CoreGeometry3D {
	let children: [Geometry3D]

	func call(in environment: Environment) -> SCADCall {
		SCADCall(name: "intersection", body: GeometrySequence(children: children))
	}
}

public extension Geometry3D {
    /// Intersect this geometry with other geometry
    ///
    /// ## Example
    /// ```swift
    /// Box([10, 10, 5])
    ///     .intersection {
    ///        Cylinder(diameter: 4, height: 3)
    ///     }
    /// ```
    ///
    /// - Parameters:
    ///   - with: The other geometry to intersect with this
    /// - Returns: The intersection (overlap) of this geometry and the input

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
    /// Intersect this geometry with other geometry
    ///
    /// ## Example
    /// ```swift
    /// Rectangle([10, 10])
    ///     .intersection {
    ///        Circle(diameter: 4)
    ///     }
    /// ```
    ///
    /// - Parameters:
    ///   - with: The other geometry to intersect with this
    /// - Returns: The intersection (overlap) of this geometry and the input

	func intersection(@UnionBuilder with other: () -> Geometry2D) -> Geometry2D {
		Intersection2D(children: [self, other()])
	}
}
