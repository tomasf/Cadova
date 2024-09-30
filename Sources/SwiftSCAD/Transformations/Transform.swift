import Foundation

struct Transform2D: TransformedGeometry2D {
    let body: any Geometry2D
    let transform: AffineTransform2D

    let moduleName = "multmatrix"
    var moduleParameters: CodeFragment.Parameters {
        ["m": AffineTransform3D(transform)]
    }
    var bodyTransform: AffineTransform2D { transform }
}

struct Transform3D: TransformedGeometry3D {
    let body: any Geometry3D
    let transform: AffineTransform3D

    let moduleName = "multmatrix"
    var moduleParameters: CodeFragment.Parameters {
        ["m": transform]
    }
    var bodyTransform: AffineTransform3D { transform }
}

public extension Geometry2D {
    /// Applies a given affine transformation to the 2D geometry.
    /// - Parameter transform: The transformation to be applied.
    /// - Returns: A transformed `Geometry2D`.
    func transformed(_ transform: AffineTransform2D) -> any Geometry2D {
        Transform2D(body: self, transform: transform)
    }

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
    /// Applies a given affine transformation to the 3D geometry.
    /// - Parameter transform: The transformation to be applied.
    /// - Returns: A transformed `Geometry3D`.
    func transformed(_ transform: AffineTransform3D) -> any Geometry3D {
        Transform3D(body: self, transform: transform)
    }

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
