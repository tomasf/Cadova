import Foundation

public extension Transform3D {
    /// Constructs a transform from an orthonormal basis and an origin.
    init(orthonormalBasisOrigin origin: Vector3D, x: Direction3D, y: Direction3D, z: Direction3D) {
        self.init([
            [x.x, y.x, z.x, origin.x],
            [x.y, y.y, z.y, origin.y],
            [x.z, y.z, z.z, origin.z],
            [0,   0,   0,   1]
        ])
    }

    /// Creates a translation `Transform3D` using the given x, y, and z offsets.
    ///
    /// - Parameters:
    ///   - x: The x-axis translation offset.
    ///   - y: The y-axis translation offset.
    ///   - z: The z-axis translation offset.
    static func translation(x: Double = 0, y: Double = 0, z: Double = 0) -> Transform3D {
        var transform = identity
        transform[0, 3] = x
        transform[1, 3] = y
        transform[2, 3] = z
        return transform
    }

    /// Creates a translation `Transform3D` using the given 3D vector.
    ///
    /// - Parameter v: The 3D vector representing the translation along each axis.
    static func translation(_ v: Vector3D) -> Transform3D {
        translation(x: v.x, y: v.y, z: v.z)
    }

    /// Creates a scaling `Transform3D` using the given x, y, and z scaling factors.
    ///
    /// - Parameters:
    ///   - x: The scaling factor along the x-axis.
    ///   - y: The scaling factor along the y-axis.
    ///   - z: The scaling factor along the z-axis.
    static func scaling(x: Double = 1, y: Double = 1, z: Double = 1) -> Transform3D {
        var transform = identity
        transform[0, 0] = x
        transform[1, 1] = y
        transform[2, 2] = z
        return transform
    }

    /// Creates a scaling `Transform3D` using the given 3D vector.
    ///
    /// - Parameter v: The 3D vector representing the scaling along each axis.
    static func scaling(_ v: Vector3D) -> Transform3D {
        scaling(x: v.x, y: v.y, z: v.z)
    }

    /// Creates a `Transform3D` for scaling all three axes uniformly
    ///
    /// - Parameter s: The scaling factor for all axes
    static func scaling(_ s: Double) -> Transform3D {
        scaling(x: s, y: s, z: s)
    }

    /// Creates a rotation `Transform3D` using the given angles for rotation along the x, y, and z axes.
    ///
    /// - Parameters:
    ///   - x: The rotation angle around the x-axis.
    ///   - y: The rotation angle around the y-axis.
    ///   - z: The rotation angle around the z-axis.
    static func rotation(x: Angle = 0°, y: Angle = 0°, z: Angle = 0°) -> Transform3D {
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

    /// Creates a rotation `Transform3D` that aligns one vector to another in 3D space.
    ///
    /// Calculate the rotation needed to align a vector `from` to another vector `to`, both in 3D space. The method ensures that the rotation minimizes the angular distance between the `from` and `to` vectors, effectively rotating around the shortest path between them.
    ///
    /// - Parameters:
    ///   - from: A `Vector3D` representing the starting orientation of the vector.
    ///   - to: A `Vector3D` representing the desired orientation of the vector.
    /// - Returns: An `Transform3D` representing the rotation from the `from` vector to the `to` vector.

    static func rotation(from: Direction3D, to: Direction3D) -> Transform3D {
        let axis = Direction3D(from.unitVector × to.unitVector)
        let angle: Angle = acos(from.unitVector ⋅ to.unitVector)
        return .rotation(angle: angle, around: axis)
    }

    /// Creates a rotation `Transform3D` around an arbitrary axis.
    ///
    /// - Parameters:
    ///   - angle: The angle of rotation.
    ///   - axis: The axis of rotation, represented as a `Direction`.
    /// - Returns: An `Transform3D` representing the rotation around the given axis.
    static func rotation(angle: Angle, around axis: Direction3D) -> Transform3D {
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

    /// Creates a shearing `Transform3D` that skews along one axis with respect to another axis.
    ///
    /// - Parameters:
    ///   - axis: The axis to shear.
    ///   - otherAxis: The axis to shear with respect to.
    ///   - factor: The shearing factor.
    static func shearing(_ axis: Axis3D, along otherAxis: Axis3D, factor: Double) -> Transform3D {
        precondition(axis != otherAxis, "Shearing requires two distinct axes")
        var t = Transform3D.identity
        t[axis.index, otherAxis.index] = factor
        return t
    }

    /// Creates a shearing `Transform3D` that skews along one axis with respect to another axis at the given angle.
    ///
    /// - Parameters:
    ///   - axis: The axis to shear.
    ///   - otherAxis: The axis to shear with respect to.
    ///   - angle: The angle of shearing.
    static func shearing(_ axis: Axis3D, along otherAxis: Axis3D, angle: Angle) -> Transform3D {
        assert(angle > -90° && angle < 90°, "Angle needs to be between -90° and 90°")
        let factor = sin(angle) / sin(90° - angle)
        return shearing(axis, along: otherAxis, factor: factor)
    }
}
