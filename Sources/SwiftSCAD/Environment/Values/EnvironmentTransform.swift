import Foundation

public extension Environment {
    static private let environmentKey = Key("SwiftSCAD.Transform")

    /// Accesses the current affine transformation applied to this environment.
    ///
    /// This property retrieves the current affine transformation from the environment, returning the identity transformation if none is set. Affine transformations are used to perform linear mapping of points in 3D space, including translations, rotations, and scaling. This property allows you to access and utilize the current transformation in effect for the geometry.
    ///
    /// - Returns: The current `AffineTransform3D` applied to the geometry. If no transformation is applied, returns `.identity`.
    var transform: AffineTransform3D {
        (self[Self.environmentKey] as? AffineTransform3D) ?? .identity
    }

    /// Returns a new environment with the specified affine transformation applied.
    ///
    /// This method allows you to apply a new affine transformation to the geometry, concatenating it with any existing transformations.
    ///
    /// - Parameter newTransform: The `AffineTransform3D` to apply.
    /// - Returns: A new `Environment` instance with the updated transformation.
    func applyingTransform(_ newTransform: AffineTransform3D) -> Environment {
        setting(key: Self.environmentKey, value:newTransform.concatenated(with: transform))
    }
}
