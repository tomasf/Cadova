import Foundation

struct Transform3D: CoreGeometry3D {
    let transform: AffineTransform
    let body: Geometry3D

    func call(in environment: Environment) -> SCADCall {
        SCADCall(
            name: "multmatrix",
            params: ["m": transform],
            body: body
        )
    }

    var bodyTransform: AffineTransform {
        transform
    }
}

public extension Geometry3D {
    /// Applies a given affine transformation to the 3D geometry.
    /// - Parameter transform: The transformation to be applied.
    /// - Returns: A transformed `Geometry3D`.
    func transformed(_ transform: AffineTransform) -> Geometry3D {
        Transform3D(transform: transform, body: self)
    }

    /// Applies a shearing transformation to the 3D geometry.
    /// - Parameters:
    ///   - axis: The primary axis that will be affected by the shear.
    ///   - otherAxis: The secondary axis that controls the direction of the shear.
    ///   - factor: The magnitude of the shear.
    /// - Returns: A sheared `Geometry3D`.
    func sheared(_ axis: Axis3D, along otherAxis: Axis3D, factor: Double) -> Geometry3D {
        transformed(.shearing(axis, along: otherAxis, factor: factor))
    }

    /// Applies a shearing transformation to the 3D geometry using an angle.
    /// - Parameters:
    ///   - axis: The primary axis that will be affected by the shear.
    ///   - otherAxis: The secondary axis that controls the direction of the shear.
    ///   - angle: The angle defining the magnitude of the shear.
    /// - Returns: A sheared `Geometry3D`.
    func sheared(_ axis: Axis3D, along otherAxis: Axis3D, angle: Angle) -> Geometry3D {
        transformed(.shearing(axis, along: otherAxis, angle: angle))
    }
}


struct Transform2D: CoreGeometry2D {
    let transform: AffineTransform2D
    let body: Geometry2D

    func call(in environment: Environment) -> SCADCall {
        SCADCall(
            name: "multmatrix",
            params: ["m": AffineTransform(transform)],
            body: body
        )
    }

    var bodyTransform: AffineTransform {
        AffineTransform(transform)
    }
}

public extension Geometry2D {
    /// Applies a given affine transformation to the 2D geometry.
    /// - Parameter transform: The transformation to be applied.
    /// - Returns: A transformed `Geometry2D`.
    func transformed(_ transform: AffineTransform2D) -> Geometry2D {
        Transform2D(transform: transform, body: self)
    }

    /// Applies a shearing transformation to the 2D geometry.
    /// - Parameters:
    ///   - axis: The primary axis that will be affected by the shear.
    ///   - otherAxis: The secondary axis that controls the direction of the shear.
    ///   - factor: The magnitude of the shear.
    /// - Returns: A sheared `Geometry2D`.
    func sheared(_ axis: Axis2D, along otherAxis: Axis2D, factor: Double) -> Geometry2D {
        transformed(.shearing(axis, along: otherAxis, factor: factor))
    }

    /// Applies a shearing transformation to the 2D geometry using an angle.
    /// - Parameters:
    ///   - axis: The primary axis that will be affected by the shear.
    ///   - otherAxis: The secondary axis that controls the direction of the shear.
    ///   - angle: The angle defining the magnitude of the shear.
    /// - Returns: A sheared `Geometry2D`.
    func sheared(_ axis: Axis2D, along otherAxis: Axis2D, angle: Angle) -> Geometry2D {
        transformed(.shearing(axis, along: otherAxis, angle: angle))
    }
}
