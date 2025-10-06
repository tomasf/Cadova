import Foundation

public extension Transformable<D2> {
    /// Applies a shearing transformation to this 2D object.
    /// - Parameters:
    ///   - axis: The primary axis that will be affected by the shear.
    ///   - factor: The magnitude of the shear.
    /// - Returns: A sheared object.
    func sheared(_ axis: Axis2D, factor: Double) -> Transformed {
        transformed(.shearing(axis, factor: factor))
    }

    /// Applies a shearing transformation to this 2D object using an angle.
    /// - Parameters:
    ///   - axis: The primary axis that will be affected by the shear.
    ///   - angle: The angle defining the magnitude of the shear.
    /// - Returns: A sheared object.
    func sheared(_ axis: Axis2D, angle: Angle) -> Transformed {
        transformed(.shearing(axis, angle: angle))
    }
}

public extension Transformable<D3> {
    /// Applies a shearing transformation to this 3D object.
    /// - Parameters:
    ///   - axis: The primary axis that will be affected by the shear.
    ///   - otherAxis: The secondary axis that controls the direction of the shear.
    ///   - factor: The magnitude of the shear.
    /// - Returns: A sheared object.
    func sheared(_ axis: Axis3D, along otherAxis: Axis3D, factor: Double) -> Transformed {
        transformed(.shearing(axis, along: otherAxis, factor: factor))
    }

    /// Applies a shearing transformation to this 3D object using an angle.
    /// - Parameters:
    ///   - axis: The primary axis that will be affected by the shear.
    ///   - otherAxis: The secondary axis that controls the direction of the shear.
    ///   - angle: The angle defining the magnitude of the shear.
    /// - Returns: A sheared object.
    func sheared(_ axis: Axis3D, along otherAxis: Axis3D, angle: Angle) -> Transformed {
        transformed(.shearing(axis, along: otherAxis, angle: angle))
    }
}
