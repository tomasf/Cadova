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

    static func rotation(axis vector: Vector3D, angle: Angle) -> AffineTransform3D {
        let axis = vector.normalized
        var transform = identity
        let c = cos(angle)
        let s = sin(angle)
        let t = 1 - c
        let x = axis.x, y = axis.y, z = axis.z
        let nx = t * x, ny = t * y

        transform[0, 0] = c + nx * x
        transform[0, 1] = nx * y - s * z
        transform[0, 2] = nx * z + s * y

        transform[1, 0] = ny * x + s * z
        transform[1, 1] = c + ny * y
        transform[1, 2] = ny * z - s * x

        transform[2, 0] = t * x * z - s * y
        transform[2, 1] = t * y * z + s * x
        transform[2, 2] = c + t * z * z

        return transform
    }

    /// Creates a rotation `AffineTransform3D` using a Rotation3D structure
    static func rotation(_ r: Rotation3D) -> AffineTransform3D {
        switch r.rotation {
        case .eulerAngles (let x, let y, let z):
            return rotation(x: x, y: y, z: z)
        case .axis(let axis, let angle):
            return rotation(axis: axis, angle: angle)
        }
    }

    /// Creates a rotation `AffineTransform3D` that aligns one vector to another in 3D space.
    ///
    /// Calculate the rotation needed to align a vector `from` to another vector `to`, both in 3D space. The method ensures that the rotation minimizes the angular distance between the `from` and `to` vectors, effectively rotating around the shortest path between them.
    ///
    /// - Parameters:
    ///   - from: A `Vector3D` representing the starting orientation of the vector.
    ///   - to: A `Vector3D` representing the desired orientation of the vector.
    /// - Returns: An `AffineTransform3D` representing the rotation from the `from` vector to the `to` vector.

    static func rotation(from: Vector3D, to: Vector3D) -> AffineTransform3D {
        let axis = from.normalized × to.normalized
        let angle: Angle = acos(from.normalized ⋅ to.normalized)
        return .rotation(axis: axis, angle: angle)
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
