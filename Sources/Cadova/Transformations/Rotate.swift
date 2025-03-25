import Foundation

public extension Geometry2D {
    /// Rotate geometry
    ///
    /// - Parameters:
    ///   - angle: The amount to rotate
    /// - Returns: A rotated geometry
    func rotated(_ angle: Angle) -> any Geometry2D {
        transformed(.rotation(angle))
    }
}

public extension Geometry3D {
    /// Rotate geometry
    ///
    /// - Parameters:
    ///   - rotation: The rotation
    /// - Returns: A rotated geometry
    func rotated(_ rotation: Rotation3D) -> any Geometry3D {
        transformed(.rotation(rotation))
    }

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
        rotated(.init(x: x, y: y, z: z))
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

    /// Rotate geometry from one direction to another.
    ///
    /// - Parameters:
    ///   - from: A `Direction3D` representing the starting orientation.
    ///   - to: A `Direction3D` representing the desired orientation.
    func rotated(from: Direction3D = .up, to: Direction3D) -> any Geometry3D {
        transformed(.rotation(from: from, to: to))
    }

    /// Rotate geometry around an arbitrary axis.
    ///
    /// - Parameters:
    ///   - angle: The angle of rotation.
    ///   - axis: The axis of rotation, represented as a `Direction`.
    func rotated(angle: Angle, around axis: Direction3D) -> any Geometry3D {
        transformed(.rotation(angle: angle, around: axis))
    }
}
