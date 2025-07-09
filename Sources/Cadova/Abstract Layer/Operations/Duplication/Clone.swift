import Foundation

public extension Geometry {
    /// Creates a composite geometry that includes this geometry and a transformed clone of it.
    ///
    /// This method applies a specified transformation to a clone of the current geometry and combines the original
    /// with the transformed clone. It is useful for combining multiple states of a geometry within a single model.
    ///
    /// - Parameter transform: A closure that takes the original geometry and returns a transformed version of it. The
    ///   transformation can include translations, rotations, scaling, or any custom modifications.
    /// - Returns: A new geometry that combines the original and the transformed clone.
    ///
    /// Example usage:
    /// ```swift
    /// let originalShape = Rectangle([10, 5])
    /// let compositeShape = originalShape.cloned { $0.rotated(45°) }
    /// ```
    /// In this example, `compositeShape` includes both the original rectangle and a version that has been translated
    /// 15 units along the x-axis.
    ///
    func cloned(@GeometryBuilder<D> _ transform: @Sendable @escaping (D.Geometry) -> D.Geometry) -> D.Geometry {
        adding { transform(self) }
    }
}

public extension Geometry2D {
    /// Creates a composite 2D geometry by adding a translated clone of the current geometry.
    ///
    /// This method duplicates the current geometry, applies a 2D translation to the clone,
    /// and combines it with the original. The result is a geometry that includes both the original
    /// and its translated version.
    ///
    /// - Parameters:
    ///   - x: The distance to translate the clone along the X axis. Defaults to `0`.
    ///   - y: The distance to translate the clone along the Y axis. Defaults to `0`.
    /// - Returns: A composite 2D geometry containing the original and the translated clone.
    ///
    /// Example:
    /// ```swift
    /// let twoCircles = Circle(radius: 2)
    ///     .clonedAt(x: 10)
    /// ```
    /// This produces two circles: the original, and another shifted 10 mm to the right.
    ///
    func clonedAt(x: Double = 0, y: Double = 0) -> any Geometry2D {
        cloned { $0.translated(x: x, y: y) }
    }
}

public extension Geometry3D {
    /// Creates a composite 3D geometry by adding a translated clone of the current geometry.
    ///
    /// This method duplicates the current geometry, applies a 3D translation to the clone,
    /// and combines it with the original. The result is a geometry that includes both the original
    /// and its translated version.
    ///
    /// - Parameters:
    ///   - x: The distance to translate the clone along the X axis. Defaults to `0`.
    ///   - y: The distance to translate the clone along the Y axis. Defaults to `0`.
    ///   - z: The distance to translate the clone along the Z axis. Defaults to `0`.
    /// - Returns: A composite 3D geometry containing the original and the translated clone.
    ///
    /// Example:
    /// ```swift
    /// let twoCylinders = Cylinder(radius: 1, height: 5)
    ///     .clonedAt(z: 10)
    /// ```
    /// This produces two cylinders: the original, and one offset 10 mm above.
    ///
    func clonedAt(x: Double = 0, y: Double = 0, z: Double = 0) -> any Geometry3D {
        cloned { $0.translated(x: x, y: y, z: z) }
    }
}
