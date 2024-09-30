import Foundation

public extension Geometry2D {
    /// Offsets the boundary of this geometry, leaving the geometry itself unmodified.
    ///
    /// The geometry remains in its current position, while its boundary is moved by the specified offset.
    /// - Parameter offset: A vector describing the amount by which to translate the boundary.
    /// - Returns: A geometry with the boundary translated by the given offset.

    func offsettingBounds(_ offset: Vector2D) -> any Geometry2D {
        ReadBoundary2D(body: self) { boundary in
            SetBounds2D(body: self, boundary: boundary.translated(offset))
        }
    }

    /// Offsets the boundary of this geometry, leaving the geometry itself unmodified.
    ///
    /// The geometry remains in its current position, while its boundary is moved by the specified offset in the `x` and `y` directions.
    /// - Parameters:
    ///   - x: The offset along the X axis to apply to the boundary. Defaults to `0`.
    ///   - y: The offset along the Y axis to apply to the boundary. Defaults to `0`.
    /// - Returns: A geometry with the boundary translated by the given offsets.

    func offsettingBounds(x: Double = 0, y: Double = 0) -> any Geometry2D {
        offsettingBounds(.init(x: x, y: y))
    }
}

public extension Geometry3D {
    /// Offsets the boundary of this geometry, leaving the geometry itself unmodified.
    ///
    /// The geometry remains in its current position, while its boundary is moved by the specified offset.
    /// - Parameter offset: A vector describing the amount by which to translate the boundary.
    /// - Returns: A geometry with the boundary translated by the given offset.

    func offsettingBounds(_ offset: Vector3D) -> any Geometry3D {
        ReadBoundary3D(body: self) { boundary in
            SetBounds3D(body: self, boundary: boundary.translated(offset))
        }
    }

    /// Offsets the boundary of this geometry, leaving the geometry itself unmodified.
    ///
    /// The geometry remains in its current position, while its boundary is moved by the specified offset in the `x` and `y` directions.
    /// - Parameters:
    ///   - x: The offset along the X axis to apply to the boundary. Defaults to `0`.
    ///   - y: The offset along the Y axis to apply to the boundary. Defaults to `0`.
    ///   - z: The offset along the Z axis to apply to the boundary. Defaults to `0`.
    /// - Returns: A geometry with the boundary translated by the given offsets.

    func offsettingBounds(x: Double = 0, y: Double = 0, z: Double = 0) -> any Geometry3D {
        offsettingBounds(.init(x: x, y: y, z: z))
    }
}
