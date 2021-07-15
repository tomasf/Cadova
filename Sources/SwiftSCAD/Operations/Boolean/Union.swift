import Foundation

struct Union3D: CoreGeometry3D {
	let children: [Geometry3D]

	init(children: [Geometry3D]) {
		self.children = children
	}

	func call(in environment: Environment) -> SCADCall {
		SCADCall(name: "union", body: GeometrySequence(children: children))
	}
}

/// Form a union to group multiple pieces of geometry together and treat them as one
///
/// ## Example
/// ```swift
/// Union {
///     Cylinder(diameter: 4)
///     Box([10, 10, 3])
/// }
/// .translate(x: 10)
/// ```
public func Union(@UnionBuilder _ body: () -> Geometry3D) -> Geometry3D {
	body()
}

public func Union(children: [Geometry3D]) -> Geometry3D {
	Union3D(children: children)
}

public extension Geometry3D {
    /// Form a union with other geometry to group them together and treat them as one
    ///
    /// ## Example
    /// ```swift
    /// Box([10, 10, 3])
    ///     .adding {
    ///         Cylinder(diameter: 5)
    ///     }
    ///     .translate(x: 10)
    /// ```
    ///
    /// - Parameter bodies: The additional geometry
    /// - Returns: A union of this geometry and `bodies`
	func adding(@SequenceBuilder _ bodies: () -> [Geometry3D]) -> Geometry3D {
		Union3D(children: [self] + bodies())
	}

    func adding(_ body: Geometry3D?) -> Geometry3D {
        guard let body = body else {
            return self
        }
        return Union3D(children: [self, body])
    }
}

struct Union2D: CoreGeometry2D {
	let children: [Geometry2D]

	init(children: [Geometry2D]) {
		self.children = children
	}

	func call(in environment: Environment) -> SCADCall {
		SCADCall(name: "union", body: GeometrySequence(children: children))
	}
}

/// Form a union to group multiple pieces of geometry together and treat them as one
///
/// ## Example
/// ```swift
/// Union {
///     Circle(diameter: 4)
///     Rectangle([10, 10])
/// }
/// .translate(x: 10)
/// ```
public func Union(@UnionBuilder _ body: () -> Geometry2D) -> Geometry2D {
	body()
}

public func Union(children: [Geometry2D]) -> Geometry2D {
	Union2D(children: children)
}

public extension Geometry2D {
    /// Form a union with other geometry to group them together and treat them as one
    ///
    /// ## Example
    /// ```swift
    /// Rectangle([10, 10])
    ///     .adding {
    ///         Circle(diameter: 5)
    ///     }
    ///     .translate(x: 10)
    /// ```
    ///
    /// - Parameter bodies: The additional geometry
    /// - Returns: A union of this geometry and `bodies`
	func adding(@SequenceBuilder _ bodies: () -> [Geometry2D]) -> Geometry2D {
		Union2D(children: [self] + bodies())
	}

    func adding(_ body: Geometry2D?) -> Geometry2D {
        guard let body = body else {
            return self
        }
        return Union2D(children: [self, body])
    }
}
