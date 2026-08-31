import Foundation

public extension EnvironmentValues {
    static private let environmentKey = Key("Cadova.Transform")
    static private let scaleKey = Key("Cadova.Scale")

    /// Accesses the current affine transformation applied to this environment.
    ///
    /// This property retrieves the current affine transformation from the environment, returning the identity
    /// transformation if none is set. Affine transformations are used to perform linear mapping of points in 3D space,
    /// including translations, rotations, and scaling. This property allows you to access and utilize the current
    /// transformation in effect for the geometry.
    ///
    /// - Returns: The current `Transform3D` applied to the geometry. If no transformation is applied,
    ///   returns `.identity`.
    ///
    var transform: Transform3D {
        (self[Self.environmentKey] as? Transform3D) ?? .identity
    }

    /// Returns a new environment with the specified affine transformation applied.
    ///
    /// This method allows you to apply a new affine transformation to the geometry, concatenating it with any existing
    /// transformations. The environment's ``scale`` is updated at the same time, using the transform's own
    /// dimensionality, so that a 2D transform contributes the scale of its X and Y axes.
    ///
    /// - Parameter newTransform: The transform to apply.
    /// - Returns: A new `EnvironmentValues` instance with the updated transformation.
    ///
    func applyingTransform<T: Transform>(_ newTransform: T) -> EnvironmentValues {
        setting([
            Self.environmentKey: newTransform.transform3D.concatenated(with: transform),
            Self.scaleKey: scale * newTransform.scaleFactor
        ])
    }
}

public extension EnvironmentValues {
    /// A single scalar that summarizes the overall scale of the current coordinate system.
    ///
    /// This value is suitable for adapting tolerances and thresholds to the local coordinate system.
    /// It accumulates the ``Transform/scaleFactor`` of every transform applied on the way down the geometry tree,
    /// where each transform contributes the smallest of its per-axis scales. At the root, this is `1.0`.
    ///
    /// Because it is a running product of per-transform factors, it is an approximation when non-uniform scaling is
    /// combined with rotation. It is exact for the common cases of uniform scaling, rotation and translation.
    ///
    var scale: Double {
        (self[Self.scaleKey] as? Double) ?? 1
    }

    /// The environment's tolerance scaled by the current coordinate system's scale.
    ///
    /// Useful for adapting tolerances to the local coordinate system.
    var scaledTolerance: Double {
        tolerance / scale
    }
}
