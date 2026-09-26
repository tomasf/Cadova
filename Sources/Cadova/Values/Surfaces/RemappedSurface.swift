import Foundation

/// A surface with a different domain than the surface it wraps.
///
/// You get one from ``ParametricSurface/remapped(u:v:)``. The shape is exactly the same as the wrapped surface; only
/// the parameter values used to address points on it change.
///
public struct RemappedSurface<Base: ParametricSurface>: ParametricSurface {
    let base: Base
    public let uDomain: ClosedRange<Double>
    public let vDomain: ClosedRange<Double>

    init(base: Base, uDomain: ClosedRange<Double>, vDomain: ClosedRange<Double>) {
        precondition(uDomain.length > 0 && vDomain.length > 0, "A surface's domain must have a nonzero length in both directions")
        self.base = base
        self.uDomain = uDomain
        self.vDomain = vDomain
    }

    public func point(at uv: Vector2D) -> Vector3D {
        base.point(atFraction: Vector2D(
            (uv.x - uDomain.lowerBound) / uDomain.length,
            (uv.y - vDomain.lowerBound) / vDomain.length
        ))
    }
}

public extension ParametricSurface {
    /// Returns the same surface with a different domain.
    ///
    /// The domain is the range of `u` and `v` values that address points on the surface. Changing it doesn't change
    /// the surface's shape, only how its points are numbered: the start of the new range is the start of the old one,
    /// and the end is the end.
    ///
    /// This matters most for `draped(over:)`, which places geometry by using its X and Y as `u` and `v`.
    /// Remapping a surface to its own size lets a design keep its real size when draped:
    ///
    /// ```swift
    /// // A 60 × 30 mm patch, whose own domain is 0...1
    /// Text("Cadova")
    ///     .extruded(height: 1)
    ///     .draped(over: patch.remapped(u: 0...60, v: 0...30))
    /// ```
    ///
    /// - Parameters:
    ///   - u: The new range of `u` values. It must have a nonzero length.
    ///   - v: The new range of `v` values. It must have a nonzero length.
    /// - Returns: The surface, addressed by the new domain.
    func remapped(u: ClosedRange<Double>, v: ClosedRange<Double>) -> RemappedSurface<Self> {
        RemappedSurface(base: self, uDomain: u, vDomain: v)
    }
}
