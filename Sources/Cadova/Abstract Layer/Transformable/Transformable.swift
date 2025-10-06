import Foundation

/// A type that can be transformed in a specific dimensional space.
///
/// Conforming types represent values that support geometric-style transforms such as
/// translation, rotation, scaling, shearing, and more.
///
/// - Note: The dimensionality `D` determines the kinds of transforms and vectors that
///   apply to the instance (for example, 2D vs. 3D).
///
public protocol Transformable<D> {
    /// The dimensionality associated with this transformable value.
    associatedtype D: Dimensionality

    /// The result type produced when a transform is applied.
    ///
    /// This may be `Self` or another type, depending on the semantics of the
    /// conforming type and the transform applied.
    associatedtype Transformed

    /// Returns the result of applying the given transform to this instance.
    ///
    /// - Parameter transform: A transform in the same dimensionality as this instance.
    /// - Returns: The transformed result.
    func transformed(_ transform: D.Transform) -> Transformed
}
