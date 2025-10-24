import Foundation

public extension Sequence where Self: Sendable {
    /// Transforms each element of the collection into geometry and returns a union of all resulting geometries.
    ///
    /// This method applies a transformation to each element in the collection, then merges all the
    /// resulting geometries into a single union. It is a convenient way to map over a sequence and
    /// produce a single grouped geometry result.
    ///
    /// This is particularly useful when working with arrays of data or parameters that define multiple
    /// shapes, all of which should be treated as one geometry.
    ///
    /// ## Example
    /// ```swift
    /// let radii = [2.0, 4.0, 6.0]
    ///
    /// let circles = radii.mapUnion { radius in
    ///     Circle(radius: radius)
    ///         .translated(x: radius * 2)
    /// }
    /// ```
    ///
    /// In this example, three circles are created and translated along the X axis, then merged into one geometry.
    ///
    /// - Parameter transform: A closure that transforms each element of the collection into a geometry.
    /// - Returns: A single geometry representing the union of all transformed geometries.

    func mapUnion<D: Dimensionality>(
        @GeometryBuilder<D> _ transform: @Sendable @escaping (Element) throws -> D.Geometry
    ) rethrows -> D.Geometry {
        Union(closure: { try map(transform) })
    }
}

public extension Sequence where Self: Sendable {
    /// Transforms each element of the sequence into geometry and returns the intersection of all resulting geometries.
    ///
    /// This method applies a transformation to each element in the sequence and intersects all resulting geometries
    /// to produce a single geometry representing their common volume or area. This is useful when combining multiple
    /// shapes and only the overlapping region is desired.
    ///
    /// ## Example
    /// ```swift
    /// let sizes = [5.0, 7.0, 9.0]
    ///
    /// let intersected = sizes.mapIntersection { size in
    ///     Rectangle([size, size])
    /// }
    /// ```
    ///
    /// In this example, three squares of different sizes are created at the origin and intersected,
    /// resulting in a geometry that matches the smallest square.
    ///
    /// - Parameter transform: A closure that transforms each element of the sequence into a geometry.
    /// - Returns: A single geometry representing the intersection of all transformed geometries.

    func mapIntersection<D: Dimensionality>(
        @GeometryBuilder<D> _ transform: @Sendable @escaping (Element) -> D.Geometry
    ) -> D.Geometry {
        Intersection(children: { map(transform) })
    }
}
