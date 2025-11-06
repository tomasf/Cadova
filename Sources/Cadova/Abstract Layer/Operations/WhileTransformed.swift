import Foundation

public extension Geometry {
    /// Temporarily applies a transform to this geometry while performing operations, then restores the original space.
    ///
    /// This helper transforms the receiver with `transform`, runs the provided operations in that transformed
    /// coordinate space, and finally applies the inverse transform to the result so it returns to the original
    /// coordinate system.
    ///
    /// - Parameters:
    ///   - transform: The transform to apply before evaluating `operations`.
    ///   - operations: A builder that produces geometry to be evaluated in the transformed space.
    /// - Returns: The resulting geometry mapped back into the original coordinate space.
    func whileTransformed(
        _ transform: D.Transform,
        @GeometryBuilder<D> do operations: (D.Geometry) -> D.Geometry
    ) -> D.Geometry {
        operations(transformed(transform)).transformed(transform.inverse)
    }
}

public extension Geometry2D {
    /// Temporarily rotates this 2D geometry while performing operations, then restores the original orientation.
    ///
    /// This applies a rotation by `rotation`, evaluates `operations` in that rotated coordinate space, and then
    /// applies the inverse rotation so the result is returned to the original 2D coordinate system.
    ///
    /// - Parameters:
    ///   - rotation: The rotation angle to apply before evaluating `operations`.
    ///   - operations: A builder that produces 2D geometry to be evaluated in the rotated space.
    /// - Returns: The resulting 2D geometry mapped back into the original coordinate space.
    func whileRotated(
        _ rotation: Angle,
        @GeometryBuilder<D> do operations: (D.Geometry) -> D.Geometry
    ) -> D.Geometry {
        whileTransformed(.rotation(rotation), do: operations)
    }
}

public extension Geometry3D {
    /// Temporarily rotates this 3D geometry while performing operations, then restores the original orientation.
    ///
    /// This applies a rotation by the specified Euler angles about the X, Y, and Z axes (in the transform’s
    /// rotation convention), evaluates `operations` in that rotated coordinate space, and then applies the
    /// inverse rotation so the result is returned to the original 3D coordinate system.
    ///
    /// - Parameters:
    ///   - x: The rotation about the X-axis to apply before evaluating `operations`. Defaults to `0°`.
    ///   - y: The rotation about the Y-axis to apply before evaluating `operations`. Defaults to `0°`.
    ///   - z: The rotation about the Z-axis to apply before evaluating `operations`. Defaults to `0°`.
    ///   - operations: A builder that produces 3D geometry to be evaluated in the rotated space.
    /// - Returns: The resulting 3D geometry mapped back into the original coordinate space.
    func whileRotated(
        x: Angle = 0°,
        y: Angle = 0°,
        z: Angle = 0°,
        @GeometryBuilder<D> do operations: (D.Geometry) -> D.Geometry
    ) -> D.Geometry {
        whileTransformed(.rotation(x: x, y: y, z: z), do: operations)
    }
}
