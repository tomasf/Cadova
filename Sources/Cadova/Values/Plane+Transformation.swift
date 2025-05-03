import Foundation

public extension Plane {
    /// Returns a new plane translated by the given 3D vector.
    ///
    /// The plane's position is shifted by the specified vector,
    /// while the orientation of its normal remains unchanged.
    ///
    /// - Parameter vector: The vector by which to translate the plane's position.
    /// - Returns: A new `Plane` instance with the updated position.
    func translated(by vector: Vector3D) -> Plane {
        Plane(offset: offset + vector, normal: normal)
    }

    /// Returns a new plane translated by the specified offsets along the x, y, and z axes.
    ///
    /// This method shifts the plane's position while preserving its normal direction.
    ///
    /// - Parameters:
    ///   - x: The translation along the x-axis. Default is `0`.
    ///   - y: The translation along the y-axis. Default is `0`.
    ///   - z: The translation along the z-axis. Default is `0`.
    /// - Returns: A new `Plane` instance with the updated position.
    func translated(x: Double = 0, y: Double = 0, z: Double = 0) -> Plane {
        translated(by: Vector3D(x, y, z))
    }
}

public extension Plane {
    private func rotated(using transform: AffineTransform3D) -> Plane {
        Plane(
            offset: transform.apply(to: offset),
            normal: .init(transform.apply(to: normal.unitVector).normalized)
        )
    }

    /// Returns a new plane rotated using the specified 3D rotation angles.
    ///
    /// The rotation affects both the plane's offset and normal direction,
    /// applying a rotation around the x, y, and z axes in order.
    ///
    /// - Parameters:
    ///   - x: The angle of rotation around the x-axis. Default is `0°`.
    ///   - y: The angle of rotation around the y-axis. Default is `0°`.
    ///   - z: The angle of rotation around the z-axis. Default is `0°`.
    /// - Returns: A new `Plane` instance with the updated orientation and position.
    func rotated(x: Angle = 0°, y: Angle = 0°, z: Angle = 0°) -> Plane {
        rotated(using: .rotation(x: x, y: y, z: z))
    }

    /// Returns a new plane rotated to align one direction to another.
    ///
    /// The rotation adjusts both the plane's position and normal,
    /// aligning the `from` direction to the `to` direction using the minimal rotation.
    ///
    /// - Parameters:
    ///   - from: The starting direction to rotate from.
    ///   - to: The target direction to rotate to.
    /// - Returns: A new `Plane` instance after applying the rotation.
    func rotated(from: Direction3D, to: Direction3D) -> Plane {
        rotated(using: .rotation(from: from, to: to))
    }

    /// Returns a new plane rotated by a specified angle around an arbitrary axis.
    ///
    /// The rotation is applied to both the plane's offset and normal direction.
    ///
    /// - Parameters:
    ///   - angle: The angle of rotation.
    ///   - axis: The axis around which to rotate.
    /// - Returns: A new `Plane` instance with the applied rotation.
    func rotated(angle: Angle, around axis: Direction3D) -> Plane {
        rotated(using: .rotation(angle: angle, around: axis))
    }
}
