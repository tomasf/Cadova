import Foundation

public extension Geometry {
    /// Applies a given affine transformation to the geometry.
    /// - Parameter transform: The transformation to be applied.
    /// - Returns: A transformed `Geometry`.
    func transformed(_ transform: D.Transform) -> D.Geometry {
        GeometryExpressionTransformer(body: self) {
            .transform($0, transform: transform)
        } environment: {
            $0.applyingTransform(transform.transform3D)
        }
    }
}

public extension Geometry2D {

    /// Applies a shearing transformation to the 2D geometry.
    /// - Parameters:
    ///   - axis: The primary axis that will be affected by the shear.
    ///   - factor: The magnitude of the shear.
    /// - Returns: A sheared `Geometry2D`.
    func sheared(_ axis: Axis2D, factor: Double) -> any Geometry2D {
        transformed(.shearing(axis, factor: factor))
    }

    /// Applies a shearing transformation to the 2D geometry using an angle.
    /// - Parameters:
    ///   - axis: The primary axis that will be affected by the shear.
    ///   - angle: The angle defining the magnitude of the shear.
    /// - Returns: A sheared `Geometry2D`.
    func sheared(_ axis: Axis2D, angle: Angle) -> any Geometry2D {
        transformed(.shearing(axis, angle: angle))
    }
}

public extension Geometry3D {
    /// Applies a shearing transformation to the 3D geometry.
    /// - Parameters:
    ///   - axis: The primary axis that will be affected by the shear.
    ///   - otherAxis: The secondary axis that controls the direction of the shear.
    ///   - factor: The magnitude of the shear.
    /// - Returns: A sheared `Geometry3D`.
    func sheared(_ axis: Axis3D, along otherAxis: Axis3D, factor: Double) -> any Geometry3D {
        transformed(.shearing(axis, along: otherAxis, factor: factor))
    }

    /// Applies a shearing transformation to the 3D geometry using an angle.
    /// - Parameters:
    ///   - axis: The primary axis that will be affected by the shear.
    ///   - otherAxis: The secondary axis that controls the direction of the shear.
    ///   - angle: The angle defining the magnitude of the shear.
    /// - Returns: A sheared `Geometry3D`.
    func sheared(_ axis: Axis3D, along otherAxis: Axis3D, angle: Angle) -> any Geometry3D {
        transformed(.shearing(axis, along: otherAxis, angle: angle))
    }
}
