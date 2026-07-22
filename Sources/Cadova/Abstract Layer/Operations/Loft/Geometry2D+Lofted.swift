import Foundation

public extension Geometry2D {
    /// Creates a 3D lofted shape between this 2D shape and another one at a given offset.
    ///
    /// This is a convenience shortcut for creating a `Loft` with two sections.
    ///
    /// The loft uses a resampling-based interpolation strategy: each shape is resampled to have matching vertex counts
    /// across sections. Both sections must have compatible topology.
    ///
    /// - Parameters:
    ///   - shapingFunction: The shaping function applied to the transition. Defaults to `.linear`.
    ///   - height: The vertical distance between the two sections.
    ///   - other: A builder that returns the 2D shape to use for the second section, placed at the specified height.
    ///
    /// - Returns: A lofted 3D shape connecting the two 2D sections.
    ///
    /// - Example:
    ///   ```swift
    ///   Circle(radius: 10)
    ///       .lofted(height: 20) {
    ///           Rectangle(20).aligned(at: .center)
    ///       }
    ///   ```
    ///   This creates a lofted shape from a circle at the base to a square at the top.
    ///
    /// - SeeAlso: `Loft`
    func lofted(
        shapingFunction: ShapingFunction = .linear,
        height: Double,
        @GeometryBuilder2D with other: @Sendable @escaping () -> any Geometry2D
    ) -> any Geometry3D {
        Loft(interpolation: shapingFunction) {
            Section(at: 0) { self }
            Section(at: height, shape: other)
        }
    }

    /// Creates a 3D lofted shape between this 2D shape and another one at a given offset,
    /// using the specified section transition.
    ///
    /// This is a convenience shortcut for creating a `Loft` with two sections.
    ///
    /// - Parameters:
    ///   - transition: The transition type that controls how the second section connects to the first.
    ///                 Use `.interpolated(_:)` for shape interpolation or `.convexHull` for a convex hull connection.
    ///   - height: The vertical distance between the two sections.
    ///   - other: A builder that returns the 2D shape to use for the second section, placed at the specified height.
    ///
    /// - Returns: A lofted 3D shape connecting the two 2D sections.
    ///
    /// - Example:
    ///   ```swift
    ///   Circle(radius: 10)
    ///       .lofted(transition: .convexHull, height: 20) {
    ///           Rectangle(20).aligned(at: .center)
    ///       }
    ///   ```
    ///
    /// - SeeAlso: `Loft`, `Loft.Transition`
    func lofted(
        transition: Loft.Transition,
        height: Double,
        @GeometryBuilder2D with other: @Sendable @escaping () -> any Geometry2D
    ) -> any Geometry3D {
        Loft {
            Section(at: 0) { self }
            Section(at: height, interpolation: transition, shape: other)
        }
    }
}
