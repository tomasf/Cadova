import Foundation

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
        Union([self] + bodies())
    }

    func adding(_ bodies: (any Geometry2D)?...) -> any Geometry2D {
        Union([self] + bodies)
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
        Union([self] + bodies())
    }

    func adding(_ bodies: (any Geometry3D)?...) -> any Geometry3D {
        Union([self] + bodies)
    }
}
