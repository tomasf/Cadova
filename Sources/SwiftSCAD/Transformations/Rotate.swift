import Foundation

struct Rotate3D: CoreGeometry3D {
    let rotation: Rotation3D
    let body: any Geometry3D

    func call(in environment: Environment) -> SCADCall {
        let params: [String: any SCADValue]

        switch rotation.rotation {
        case .eulerAngles(let x, let y, let z):
            params = ["a": [x, y, z]]
        case .axis(let v, let angle):
            params = ["a": angle, "v": [v.x, v.y, v.z]]
        }

        return SCADCall(name: "rotate", params: params, body: body)
    }

    var bodyTransform: AffineTransform3D {
        .rotation(rotation)
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
        Rotate3D(rotation: .init(x: x, y: y, z: z), body: self)
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
        Rotate3D(rotation: .init(axis: axis, angle: angle), body: self)
    }

    /// Rotate geometry
    ///
    /// When using multiple axes, the geometry is rotated around the axes in order (first X, then Y, then Z).
    ///
    /// - Parameters:
    ///   - rotation: The rotation
    /// - Returns: A rotated geometry
    func rotated(_ rotation: Rotation3D) -> any Geometry3D {
        Rotate3D(rotation: rotation, body: self)
    }
}


struct Rotate2D: CoreGeometry2D {
    let angle: Angle
    let body: any Geometry2D

    func call(in environment: Environment) -> SCADCall {
        return SCADCall(
            name: "rotate",
            params: ["a": angle],
            body: body
        )
    }

    var bodyTransform: AffineTransform3D {
        .rotation(z: angle)
    }
}

public extension Geometry2D {
    /// Rotate geometry
    ///
    /// - Parameters:
    ///   - angle: The amount to rotate
    /// - Returns: A rotated geometry
    func rotated(_ angle: Angle) -> any Geometry2D {
        Rotate2D(angle: angle, body: self)
    }
}
