import Foundation

public extension Geometry {
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
    func adding(@GeometryBuilder<D> _ bodies: () -> D.Geometry) -> D.Geometry {
        bodies()
    }

    func adding(_ bodies: D.Geometry?...) -> D.Geometry {
        Union([self] + bodies)
    }
}
