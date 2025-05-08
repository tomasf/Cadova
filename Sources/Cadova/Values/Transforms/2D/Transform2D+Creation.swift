import Foundation

public extension Transform2D {
    /// Creates a translation `Transform2D` using the given x and y offsets.
    ///
    /// - Parameters:
    ///   - x: The x-axis translation offset.
    ///   - y: The y-axis translation offset.
    static func translation(x: Double = 0, y: Double = 0) -> Transform2D {
        var transform = identity
        transform[0, 2] = x
        transform[1, 2] = y
        return transform
    }

    /// Creates a translation `Transform2D` using the given 2D vector.
    ///
    /// - Parameter v: The 2D vector representing the translation along x and y axes.
    static func translation(_ v: Vector2D) -> Transform2D {
        translation(x: v.x, y: v.y)
    }

    /// Creates a scaling `Transform2D` using the given x and y scaling factors.
    ///
    /// - Parameters:
    ///   - x: The scaling factor along the x-axis.
    ///   - y: The scaling factor along the y-axis.
    static func scaling(x: Double = 1, y: Double = 1) -> Transform2D {
        var transform = identity
        transform[0, 0] = x
        transform[1, 1] = y
        return transform
    }

    /// Creates a scaling `Transform2D` using the given 2D vector.
    ///
    /// - Parameter v: The 2D vector representing the scaling along x and y axes.
    static func scaling(_ v: Vector2D) -> Transform2D {
        scaling(x: v.x, y: v.y)
    }

    /// Creates a rotation `Transform2D` using the given angle for rotation.
    ///
    /// - Parameter angle: The rotation angle.
    static func rotation(_ angle: Angle) -> Transform2D {
        var transform = identity
        transform[0, 0] = cos(angle)
        transform[0, 1] = -sin(angle)
        transform[1, 0] = sin(angle)
        transform[1, 1] = cos(angle)
        return transform
    }

    /// Creates a shearing `Transform2D` that skews along one axis with respect to another axis.
    ///
    /// - Parameters:
    ///   - axis: The axis to shear.
    ///   - factor: The shearing factor.
    static func shearing(_ axis: Axis2D, factor: Double) -> Transform2D {
        var transform = Transform2D.identity
        if axis == .x {
            transform[1, 0] = factor
        } else {
            transform[0, 1] = factor
        }
        return transform
    }

    /// Creates a shearing `Transform2D` that skews along one axis with respect to another axis at the given angle.
    ///
    /// - Parameters:
    ///   - axis: The axis to shear.
    ///   - angle: The angle of shearing.
    static func shearing(_ axis: Axis2D, angle: Angle) -> Transform2D {
        assert(angle > -90° && angle < 90°, "Angle needs to be between -90° and 90°")
        let factor = sin(angle) / sin(90° - angle)
        return shearing(axis, factor: factor)
    }
}
