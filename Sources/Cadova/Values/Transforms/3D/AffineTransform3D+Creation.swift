import Foundation

public extension AffineTransform3D {
    /// Creates a translation `AffineTransform3D` using the given x, y, and z offsets.
    ///
    /// - Parameters:
    ///   - x: The x-axis translation offset.
    ///   - y: The y-axis translation offset.
    ///   - z: The z-axis translation offset.
    static func translation(x: Double = 0, y: Double = 0, z: Double = 0) -> AffineTransform3D {
        var transform = identity
        transform[0, 3] = x
        transform[1, 3] = y
        transform[2, 3] = z
        return transform
    }

    /// Creates a translation `AffineTransform3D` using the given 3D vector.
    ///
    /// - Parameter v: The 3D vector representing the translation along each axis.
    static func translation(_ v: Vector3D) -> AffineTransform3D {
        translation(x: v.x, y: v.y, z: v.z)
    }

    /// Creates a scaling `AffineTransform3D` using the given x, y, and z scaling factors.
    ///
    /// - Parameters:
    ///   - x: The scaling factor along the x-axis.
    ///   - y: The scaling factor along the y-axis.
    ///   - z: The scaling factor along the z-axis.
    static func scaling(x: Double = 1, y: Double = 1, z: Double = 1) -> AffineTransform3D {
        var transform = identity
        transform[0, 0] = x
        transform[1, 1] = y
        transform[2, 2] = z
        return transform
    }

    /// Creates a scaling `AffineTransform3D` using the given 3D vector.
    ///
    /// - Parameter v: The 3D vector representing the scaling along each axis.
    static func scaling(_ v: Vector3D) -> AffineTransform3D {
        scaling(x: v.x, y: v.y, z: v.z)
    }

    /// Creates a `AffineTransform3D` for scaling all three axes uniformly
    ///
    /// - Parameter s: The scaling factor for all axes
    static func scaling(_ s: Double) -> AffineTransform3D {
        scaling(x: s, y: s, z: s)
    }

    /// Creates a rotation `AffineTransform3D` using the given angles for rotation along the x, y, and z axes.
    ///
    /// - Parameters:
    ///   - x: The rotation angle around the x-axis.
    ///   - y: The rotation angle around the y-axis.
    ///   - z: The rotation angle around the z-axis.
    static func rotation(x: Angle = 0°, y: Angle = 0°, z: Angle = 0°) -> AffineTransform3D {
        var transform = identity
        transform[0, 0] = cos(y) * cos(z)
        transform[0, 1] = sin(x) * sin(y) * cos(z) - cos(x) * sin(z)
        transform[0, 2] = cos(x) * sin(y) * cos(z) + sin(z) * sin(x)
        transform[1, 0] = cos(y) * sin(z)
        transform[1, 1] = sin(x) * sin(y) * sin(z) + cos(x) * cos(z)
        transform[1, 2] = cos(x) * sin(y) * sin(z) - sin(x) * cos(z)
        transform[2, 0] = -sin(y)
        transform[2, 1] = sin(x) * cos(y)
        transform[2, 2] = cos(x) * cos(y)
        return transform
    }

    /// Creates a rotation `AffineTransform3D` using a Rotation3D structure
    ///
    /// - Parameter r: The `Rotation3D` describing the desired 3D rotation.
    /// - Returns: An `AffineTransform3D` representing the corresponding rotation.
    static func rotation(_ r: Rotation3D) -> AffineTransform3D {
        let x = r.qx, y = r.qy, z = r.qz, w = r.qw

        let xx = x * x
        let yy = y * y
        let zz = z * z
        let xy = x * y
        let xz = x * z
        let yz = y * z
        let wx = w * x
        let wy = w * y
        let wz = w * z

        var transform = identity
        transform[0, 0] = 1 - 2 * (yy + zz)
        transform[0, 1] = 2 * (xy - wz)
        transform[0, 2] = 2 * (xz + wy)
        transform[1, 0] = 2 * (xy + wz)
        transform[1, 1] = 1 - 2 * (xx + zz)
        transform[1, 2] = 2 * (yz - wx)
        transform[2, 0] = 2 * (xz - wy)
        transform[2, 1] = 2 * (yz + wx)
        transform[2, 2] = 1 - 2 * (xx + yy)
        return transform
    }

    /// Creates a rotation `AffineTransform3D` that aligns one vector to another in 3D space.
    ///
    /// Calculate the rotation needed to align a vector `from` to another vector `to`, both in 3D space. The method ensures that the rotation minimizes the angular distance between the `from` and `to` vectors, effectively rotating around the shortest path between them.
    ///
    /// - Parameters:
    ///   - from: A `Vector3D` representing the starting orientation of the vector.
    ///   - to: A `Vector3D` representing the desired orientation of the vector.
    /// - Returns: An `AffineTransform3D` representing the rotation from the `from` vector to the `to` vector.

    static func rotation(from: Direction3D, to: Direction3D) -> AffineTransform3D {
        let axis = Direction3D(vector: from.unitVector × to.unitVector)
        let angle: Angle = acos(from.unitVector ⋅ to.unitVector)
        return .rotation(angle: angle, around: axis)
    }

    /// Creates a rotation `AffineTransform3D` around an arbitrary axis.
    ///
    /// - Parameters:
    ///   - angle: The angle of rotation.
    ///   - axis: The axis of rotation, represented as a `Direction`.
    /// - Returns: An `AffineTransform3D` representing the rotation around the given axis.
    static func rotation(angle: Angle, around axis: Direction3D) -> AffineTransform3D {
        let x = axis.unitVector.x
        let y = axis.unitVector.y
        let z = axis.unitVector.z

        let c = cos(angle)
        let s = sin(angle)
        let t = 1 - c

        var transform = identity
        transform[0, 0] = c + t * x * x
        transform[0, 1] = t * x * y - s * z
        transform[0, 2] = t * x * z + s * y

        transform[1, 0] = t * y * x + s * z
        transform[1, 1] = c + t * y * y
        transform[1, 2] = t * y * z - s * x

        transform[2, 0] = t * z * x - s * y
        transform[2, 1] = t * z * y + s * x
        transform[2, 2] = c + t * z * z

        return transform
    }

    /// Creates a shearing `AffineTransform3D` that skews along one axis with respect to another axis.
    ///
    /// - Parameters:
    ///   - axis: The axis to shear.
    ///   - otherAxis: The axis to shear with respect to.
    ///   - factor: The shearing factor.
    static func shearing(_ axis: Axis3D, along otherAxis: Axis3D, factor: Double) -> AffineTransform3D {
        precondition(axis != otherAxis, "Shearing requires two distinct axes")
        var t = AffineTransform3D.identity
        t[axis.index, otherAxis.index] = factor
        return t
    }

    /// Creates a shearing `AffineTransform3D` that skews along one axis with respect to another axis at the given angle.
    ///
    /// - Parameters:
    ///   - axis: The axis to shear.
    ///   - otherAxis: The axis to shear with respect to.
    ///   - angle: The angle of shearing.
    static func shearing(_ axis: Axis3D, along otherAxis: Axis3D, angle: Angle) -> AffineTransform3D {
        assert(angle > -90° && angle < 90°, "Angle needs to be between -90° and 90°")
        let factor = sin(angle) / sin(90° - angle)
        return shearing(axis, along: otherAxis, factor: factor)
    }
}
