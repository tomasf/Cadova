import Foundation

struct Union2D: Geometry2D {
    let children: [any Geometry2D]

    func output(in environment: Environment) -> GeometryOutput2D {
        .init(
            invocation: .init(name: "union"),
            body: children,
            environment: environment,
            boundaryMergeStrategy: .union
        )
    }
}

struct Union3D: Geometry3D {
    let children: [any Geometry3D]

    func output(in environment: Environment) -> GeometryOutput3D {
        .init(
            invocation: .init(name: "union"),
            body: children,
            environment: environment,
            boundaryMergeStrategy: .union
        )
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
public func Union(@UnionBuilder2D _ body: () -> any Geometry2D) -> any Geometry2D {
    body()
}

public func Union(children: [any Geometry2D]) -> any Geometry2D {
    Union2D(children: children)
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
public func Union(@UnionBuilder3D _ body: () -> any Geometry3D) -> any Geometry3D {
    body()
}

public func Union(children: [any Geometry3D]) -> any Geometry3D {
    Union3D(children: children)
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
    func adding(@SequenceBuilder2D _ bodies: () -> [any Geometry2D]) -> any Geometry2D {
        Union2D(children: [self] + bodies())
    }

    func adding(_ bodies: (any Geometry2D)?...) -> any Geometry2D {
        Union2D(children: [self] + bodies.compactMap { $0 })
    }
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
    func adding(@SequenceBuilder3D _ bodies: () -> [any Geometry3D]) -> any Geometry3D {
        Union3D(children: [self] + bodies())
    }

    func adding(_ bodies: (any Geometry3D)?...) -> any Geometry3D {
        Union3D(children: [self] + bodies.compactMap { $0 })
    }
}

public extension Sequence {
    func mapUnion(@UnionBuilder3D _ transform: (Element) throws -> any Geometry3D) rethrows -> any Geometry3D {
        Union3D(children: try map(transform))
    }

    func mapUnion(@UnionBuilder2D _ transform: (Element) throws -> any Geometry2D) rethrows -> any Geometry2D {
        Union2D(children: try map(transform))
    }
}
