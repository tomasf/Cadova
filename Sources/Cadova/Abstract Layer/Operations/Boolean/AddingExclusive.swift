import Foundation

public extension Geometry {
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
    /// ```swift
    /// Box([10, 10, 5])
    ///     .addingExclusive(Sphere(diameter: 5))
    /// ```
    ///
    /// - Parameter body: The additional geometry to combine with.
    /// - Returns: A new geometry that is the union of this geometry and `body`,
    ///            excluding their intersection.
    func addingExclusive(_ body: D.Geometry) -> D.Geometry {
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
    func addingExclusive(@GeometryBuilder<D> _ body: () -> D.Geometry) -> D.Geometry {
        addingExclusive(body())
    }
}
