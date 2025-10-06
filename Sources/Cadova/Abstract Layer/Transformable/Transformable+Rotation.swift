import Foundation

public extension Transformable<D2> {
    /// Rotate object
    ///
    /// - Parameters:
    ///   - angle: The amount to rotate
    /// - Returns: A rotated object
    func rotated(_ angle: Angle) -> Transformed {
        transformed(.rotation(angle))
    }
}

public extension Transformable<D3> {
    /// Rotate object
    ///
    /// When using multiple axes, the object is rotated around the axes in order (first X, then Y, then Z).
    ///
    /// - Parameters:
    ///   - x: The amount to rotate around the X axis
    ///   - y: The amount to rotate around the Y axis
    ///   - z: The amount to rotate around the Z axis
    /// - Returns: A rotated object
    func rotated(x: Angle = 0°, y: Angle = 0°, z: Angle = 0°) -> Transformed {
        transformed(.rotation(x: x, y: y, z: z))
    }

    /// Rotate around a cartesian axis
    ///
    /// - Parameters:
    ///   - angle: The angle to rotate
    ///   - axis: The cartesian axis to rotate around
    /// - Returns: A rotated object
    func rotated(angle: Angle, axis: Axis3D) -> Transformed {
        switch axis {
        case .x: return rotated(x: angle)
        case .y: return rotated(y: angle)
        case .z: return rotated(z: angle)
        }
    }

    /// Rotate object from one direction to another.
    ///
    /// - Parameters:
    ///   - from: A `Direction3D` representing the starting orientation.
    ///   - to: A `Direction3D` representing the desired orientation.
    func rotated(from: Direction3D = .up, to: Direction3D) -> Transformed {
        transformed(.rotation(from: from, to: to))
    }

    /// Rotate object around an arbitrary axis.
    ///
    /// - Parameters:
    ///   - angle: The angle of rotation.
    ///   - axis: The axis of rotation, represented as a `Direction`.
    func rotated(angle: Angle, around axis: Direction3D) -> Transformed {
        transformed(.rotation(angle: angle, around: axis))
    }
}
