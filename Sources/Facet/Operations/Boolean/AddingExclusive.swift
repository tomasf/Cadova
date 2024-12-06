import Foundation

public extension Geometry2D {
    /// Form a union with another geometry, excluding their intersection.
    ///
    /// The `addingExclusive` method combines this geometry with another while
    /// excluding the region where the two geometries overlap. This is equivalent
    /// to the XOR operation in set theory, where only the non-overlapping regions
    /// are retained.
    ///
    /// ## Example
    /// ```swift
    /// Rectangle(10)
    ///     .addingExclusive(Circle(diameter: 5))
    /// ```
    ///
    /// - Parameter body: The additional geometry to combine with.
    /// - Returns: A new geometry that is the union of this geometry and `body`,
    ///            excluding their intersection.
    func addingExclusive(_ body: any Geometry2D) -> any Geometry2D {
        adding(body).subtracting(intersecting(body))
    }

    /// Form a union with other geometry defined by a builder, excluding their intersection.
    ///
    /// The `addingExclusive` method allows you to use a geometry builder to define
    /// additional geometries to combine with this one while excluding their intersection.
    ///
    /// ## Example
    /// ```swift
    /// Rectangle([10, 10])
    ///     .addingExclusive {
    ///         Circle(diameter: 5)
    ///     }
    /// ```
    ///
    /// - Parameter body: A geometry builder that provides the geometries to combine with.
    /// - Returns: A new geometry that is the union of this geometry and the result of
    ///            the geometry builder, excluding their intersection.
    func addingExclusive(@GeometryBuilder2D _ body: () -> any Geometry2D) -> any Geometry2D {
        addingExclusive(body())
    }
}

public extension Geometry3D {
    /// Form a union with another 3D geometry, excluding their intersection.
    ///
    /// The `addingExclusive` method combines this geometry with another while
    /// excluding the region where the two geometries overlap. This is equivalent
    /// to the XOR operation in set theory, where only the non-overlapping regions
    /// are retained.
    ///
    /// ## Example
    /// ```swift
    /// Box([10, 10, 5])
    ///     .addingExclusive(Sphere(diameter: 5))
    /// ```
    ///
    /// - Parameter body: The additional geometry to combine with.
    /// - Returns: A new geometry that is the union of this geometry and `body`,
    ///            excluding their intersection.
    func addingExclusive(_ body: any Geometry3D) -> any Geometry3D {
        adding(body).subtracting(intersecting(body))
    }

    /// Form a union with other 3D geometry defined by a builder, excluding their intersection.
    ///
    /// The `addingExclusive` method allows you to use a geometry builder to define
    /// additional geometries to combine with this one while excluding their intersection.
    ///
    /// ## Example
    /// ```swift
    /// Box([10, 10, 5])
    ///     .addingExclusive {
    ///         Sphere(diameter: 5)
    ///     }
    /// ```
    ///
    /// - Parameter body: A geometry builder that provides the geometries to combine with.
    /// - Returns: A new geometry that is the union of this geometry and the result of
    ///            the geometry builder, excluding their intersection.
    func addingExclusive(@GeometryBuilder3D _ body: () -> any Geometry3D) -> any Geometry3D {
        addingExclusive(body())
    }
}
