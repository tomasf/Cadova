import Foundation

fileprivate struct Transform<V: Vector> where V.Transform: AffineTransformInternal {
    let body: V.Geometry
    let transform: V.Transform

    let moduleName = "multmatrix"
    var moduleParameters: CodeFragment.Parameters {
        ["m": transform.transform3D]
    }
    var bodyTransform: V.Transform { transform }
}

extension Transform<Vector2D>: Geometry2D, TransformedGeometry2D {}
extension Transform<Vector3D>: Geometry3D, TransformedGeometry3D {}

public extension Geometry2D {
    /// Applies a given affine transformation to the 2D geometry.
    /// - Parameter transform: The transformation to be applied.
    /// - Returns: A transformed `Geometry2D`.
    func transformed(_ transform: AffineTransform2D) -> any Geometry2D {
        Transform(body: self, transform: transform)
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
        Transform(body: self, transform: transform)
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
