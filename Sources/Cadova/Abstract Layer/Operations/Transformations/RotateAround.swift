import Foundation

// A single `around` parameter label + the `_` parameter in these methods is needed in order for the normal rotated(x:y:[z:]) methods
// to be prioritized over these. Without this, we get infinite recursion when these methods call themselves.

public extension Geometry2D {
    /// Rotates the geometry around a specified pivot point in 2D space.
    ///
    /// This method rotates the geometry by the specified angle in the 2D plane. The rotation occurs around a pivot
    /// point, which is defined by alignment options. The pivot is determined based on the bounding box of the geometry.
    ///
    /// - Parameters:
    ///   - angle: The angle to rotate the geometry. Defaults to `0°`.
    ///   - pivot: A list of alignment options that specify the pivot point for the rotation. For example, `.center`
    ///     can be used to rotate the geometry around its center, while `.top` can rotate it around the top boundary.
    ///
    /// - Returns: A new geometry that is the result of applying the specified rotation and pivot adjustments.
    ///
    /// Example:
    /// ```
    /// Rectangle([10, 8])
    ///     .rotated(45°, around: .center)
    /// ```
    /// This example rotates the square 45 degrees around its center.
    /// 
    func rotated(
        _ angle: Angle = 0°,
        around pivot: GeometryAlignment2D,
        _ more: GeometryAlignment2D...
    ) -> any Geometry2D {
        measuringBounds { _, bounds in
            let alignment = ([pivot] + more).merged
            let translation = bounds.translation(for: alignment)
            self
                .translated(translation)
                .rotated(angle)
                .translated(-translation)
        }
    }
}

public extension Geometry3D {
    /// Rotates the geometry around a specified pivot point in 3D space.
    ///
    /// This method rotates the geometry by the specified angles along the X, Y, and Z axes. When using multiple axes,
    /// the geometry is rotated around the axes in order (first X, then Y, then Z). The rotation occurs around a pivot
    /// point, which is defined by alignment options. The pivot is determined based on the bounding box of the geometry.
    ///
    /// - Parameters:
    ///   - x: The angle to rotate around the X-axis. Defaults to `0°`.
    ///   - y: The angle to rotate around the Y-axis. Defaults to `0°`.
    ///   - z: The angle to rotate around the Z-axis. Defaults to `0°`.
    ///   - pivot: A list of alignment options that specify the pivot point for the rotation. For example, `.center`
    ///     can be used to rotate the geometry around its center, while `.top` can rotate it around the top boundary.
    ///
    /// - Returns: A new geometry that is the result of applying the specified rotation and pivot adjustments.
    ///
    /// Example:
    /// ```
    /// Box([10, 10, 5])
    ///     .rotated(x: 90°, around: .center)
    /// ```
    /// This example rotates the box 90 degrees around its center.
    /// 
    func rotated(
        x: Angle = 0°,
        y: Angle = 0°,
        z: Angle = 0°,
        around pivot: GeometryAlignment3D,
        _ more: GeometryAlignment3D...
    ) -> any Geometry3D {
        measuringBounds { _, box in
            let alignment = ([pivot] + more).merged
            let translation = box.translation(for: alignment)
            self
                .translated(translation)
                .rotated(x: x, y: y, z: z)
                .translated(-translation)
        }
    }

    /// Rotates the geometry around an arbitrary axis defined by a 3D line.
    ///
    /// The axis of rotation is given by the line’s direction and passes through a point on the line.
    ///
    /// - Parameters:
    ///   - angle: The angle to rotate around the axis.
    ///   - axis: A line in 3D defining the rotation axis (direction) and the point it passes through.
    /// - Returns: A new geometry that is the result of applying the specified rotation around the line.
    ///
    func rotated(_ angle: Angle, around axis: Line<D3>) -> any Geometry3D {
        self
            .translated(-axis.point)
            .transformed(.rotation(angle: angle, around: axis.direction))
            .translated(axis.point)
    }
}
