import Foundation

struct Rotate2D: TransformedGeometry2D {
    let body: any Geometry2D
    let angle: Angle

    let invocationName = "rotate"
    var invocationParameters: Invocation.Parameters {
        ["a": angle]
    }
    var bodyTransform: AffineTransform2D { .rotation(angle) }
}

struct Rotate3D: TransformedGeometry3D {
    let body: any Geometry3D
    let rotation: Rotation3D

    let invocationName = "rotate"
    var invocationParameters: Invocation.Parameters {
        switch rotation.rotation {
        case .eulerAngles(let x, let y, let z):
            ["a": [x, y, z]]
        case .axis(let v, let angle):
            ["a": angle, "v": [v.x, v.y, v.z]]
        }
    }
    var bodyTransform: AffineTransform3D { .rotation(rotation) }
}

public extension Geometry2D {
    /// Rotate geometry
    ///
    /// - Parameters:
    ///   - angle: The amount to rotate
    /// - Returns: A rotated geometry
    func rotated(_ angle: Angle) -> any Geometry2D {
        Rotate2D(body: self, angle: angle)
    }
}

public extension Geometry3D {
    /// Rotate geometry
    ///
    /// When using multiple axes, the geometry is rotated around the axes in order (first X, then Y, then Z).
    ///
    /// - Parameters:
    ///   - x: The amount to rotate around the X axis
    ///   - y: The amount to rotate around the Y axis
    ///   - z: The amount to rotate around the Z axis
    /// - Returns: A rotated geometry
    func rotated(x: Angle = 0°, y: Angle = 0°, z: Angle = 0°) -> any Geometry3D {
        Rotate3D(body: self, rotation: .init(x: x, y: y, z: z))
    }

    /// Rotate around a cartesian axis
    ///
    /// - Parameters:
    ///   - angle: The angle to rotate
    ///   - axis: The cartesian axis to rotate around
    /// - Returns: A rotated geometry
    func rotated(angle: Angle, axis: Axis3D) -> any Geometry3D {
        switch axis {
        case .x: return rotated(x: angle)
        case .y: return rotated(y: angle)
        case .z: return rotated(z: angle)
        }
    }

    /// Rotate around an arbitrary axis defined by a 3D vector and an angle.
    ///
    /// This modifier is used for rotating around an axis that is not necessarily aligned with the principal axes.
    ///
    /// - Parameters:
    ///   - angle: The angle of rotation around the specified axis.
    ///   - axis: The 3D vector defining the axis of rotation.
    func rotated(angle: Angle, axis: Vector3D) -> any Geometry3D {
        rotated(.init(angle: angle, axis: axis))
    }

    /// Rotate geometry
    ///
    /// When using multiple axes, the geometry is rotated around the axes in order (first X, then Y, then Z).
    ///
    /// - Parameters:
    ///   - rotation: The rotation
    /// - Returns: A rotated geometry
    func rotated(_ rotation: Rotation3D) -> any Geometry3D {
        Rotate3D(body: self, rotation: rotation)
    }

    /// Rotate geometry from one direction vector to another.
    ///
    /// - Parameters:
    ///   - from: A `Vector3D` representing the starting orientation of the vector.
    ///   - to: A `Vector3D` representing the desired orientation of the vector.
    /// - Returns: An `AffineTransform3D` representing the rotation from the `from` vector to the `to` vector.

    func rotated(from: Vector3D = .up, to: Vector3D) -> any Geometry3D {
        transformed(.rotation(from: from, to: to))
    }
}
