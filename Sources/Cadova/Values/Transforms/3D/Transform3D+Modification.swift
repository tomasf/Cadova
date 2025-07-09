import Foundation

public extension Transform3D {
    /// Creates a new `Transform3D` by concatenating a translation with this transformation.
    ///
    /// - Parameters:
    ///   - x: The x-axis translation offset.
    ///   - y: The y-axis translation offset.
    ///   - z: The z-axis translation offset.
    func translated(x: Double = 0, y: Double = 0, z: Double = 0) -> Transform3D {
        concatenated(with: .translation(x: x, y: y, z: z))
    }

    /// Creates a new `Transform3D` by concatenating a scaling transformation with this transformation.
    ///
    /// - Parameters:
    ///   - x: The scaling factor along the x-axis.
    ///   - y: The scaling factor along the y-axis.
    ///   - z: The scaling factor along the z-axis.
    func scaled(x: Double = 1, y: Double = 1, z: Double = 1) -> Transform3D {
        concatenated(with: .scaling(x: x, y: y, z: z))
    }

    /// Creates a new `Transform3D` by concatenating a rotation transformation with this transformation using the given
    /// angles for rotation.
    ///
    /// - Parameters:
    ///   - x: The rotation angle around the x-axis.
    ///   - y: The rotation angle around the y-axis.
    ///   - z: The rotation angle around the z-axis.
    func rotated(x: Angle = 0°, y: Angle = 0°, z: Angle = 0°) -> Transform3D {
        concatenated(with: .rotation(x: x, y: y, z: z))
    }

    /// Creates a new `Transform3D` by concatenating a rotation transformation aligning one vector to another in 3D
    /// space.
    ///
    /// Calculate the rotation needed to align a vector `from` to another vector `to`, both in 3D space. The method
    /// ensures that the rotation minimizes the angular distance between the `from` and `to` vectors, effectively
    /// rotating around the shortest path between them.
    ///
    /// - Parameters:
    ///   - from: A `Vector3D` representing the starting orientation of the vector.
    ///   - to: A `Vector3D` representing the desired orientation of the vector.
    /// - Returns: An `Transform3D` adding the rotation from the `from` vector to the `to` vector.

    func rotated(from: Direction3D, to: Direction3D) -> Transform3D {
        concatenated(with: .rotation(from: from, to: to))
    }

    /// Creates a new `Transform3D` by concatenating a rotation around an arbitrary axis.
    ///
    /// - Parameters:
    ///   - angle: The angle of rotation.
    ///   - axis: The axis of rotation, represented as a `Direction`.
    /// - Returns: An `Transform3D` adding the rotation.
    func rotated(angle: Angle, around axis: Direction3D) -> Transform3D {
        concatenated(with: .rotation(angle: angle, around: axis))
    }

    /// Creates a new `Transform3D` by concatenating a shearing transformation with this transformation.
    ///
    /// - Parameters:
    ///   - axis: The axis to shear.
    ///   - otherAxis: The axis to shear with respect to.
    ///   - factor: The shearing factor.
    func sheared(_ axis: Axis3D, along otherAxis: Axis3D, factor: Double) -> Transform3D {
        concatenated(with: .shearing(axis, along: otherAxis, factor: factor))
    }

    /// Creates a new `Transform3D` by concatenating a shearing transformation with this transformation at the given
    /// angle.
    ///
    /// - Parameters:
    ///   - axis: The axis to shear.
    ///   - otherAxis: The axis to shear with respect to.
    ///   - angle: The angle of shearing.
    func sheared(_ axis: Axis3D, along otherAxis: Axis3D, angle: Angle) -> Transform3D {
        concatenated(with: .shearing(axis, along: otherAxis, angle: angle))
    }
}
