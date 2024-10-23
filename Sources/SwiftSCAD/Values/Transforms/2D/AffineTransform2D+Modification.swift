import Foundation

public extension AffineTransform2D {
    /// Creates a new `AffineTransform2D` by concatenating a translation with this transformation.
    ///
    /// - Parameters:
    ///   - x: The x-axis translation offset.
    ///   - y: The y-axis translation offset.
    func translated(x: Double = 0, y: Double = 0) -> AffineTransform2D {
        concatenated(with: .translation(x: x, y: y))
    }

    /// Creates a new `AffineTransform2D` by concatenating a translation with this transformation using the given 2D vector.
    ///
    /// - Parameter v: The 2D vector representing the translation along x and y axes.
    func translated(_ v: Vector2D) -> AffineTransform2D {
        concatenated(with: .translation(v))
    }

    /// Creates a new `AffineTransform2D` by concatenating a scaling transformation with this transformation using the given 2D vector.
    ///
    /// - Parameter v: The 2D vector representing the scaling along x and y axes.
    func scaled(_ v: Vector2D) -> AffineTransform2D {
        concatenated(with: .scaling(v))
    }

    /// Creates a new `AffineTransform2D` by concatenating a scaling transformation with this transformation.
    ///
    /// - Parameters:
    ///   - x: The scaling factor along the x-axis.
    ///   - y: The scaling factor along the y-axis.
    func scaled(x: Double = 1, y: Double = 1) -> AffineTransform2D {
        concatenated(with: .scaling(x: x, y: y))
    }

    /// Creates a new `AffineTransform2D` by concatenating a rotation transformation with this transformation.
    ///
    /// - Parameter angle: The rotation angle.
    func rotated(_ angle: Angle) -> AffineTransform2D {
        concatenated(with: .rotation(angle))
    }

    /// Creates a new `AffineTransform2D` by concatenating a shearing transformation with this transformation.
    ///
    /// - Parameters:
    ///   - axis: The axis to shear.
    ///   - factor: The shearing factor.
    func sheared(_ axis: Axis2D, factor: Double) -> AffineTransform2D {
        concatenated(with: .shearing(axis, factor: factor))
    }

    /// Creates a new `AffineTransform2D` by concatenating a shearing transformation with this transformation at the given angle.
    ///
    /// - Parameters:
    ///   - axis: The axis to shear.
    ///   - angle: The angle of shearing.
    func sheared(_ axis: Axis2D, angle: Angle) -> AffineTransform2D {
        concatenated(with: .shearing(axis, angle: angle))
    }
}
