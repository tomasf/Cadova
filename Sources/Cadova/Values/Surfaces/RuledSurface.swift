import Foundation

/// A surface made of straight lines spanned between two curves.
///
/// Each point on the first curve is joined by a straight line to the point on the second curve that lies the same
/// fraction of the way along it, measured by length. Two straight lines make a flat or twisted quad, a line and a
/// curve make a fan-like sweep, and two curves make a smooth transition between them, such as a twisted ribbon or
/// the flank of a hull.
///
/// ```swift
/// let straight = BezierPath3D(linesBetween: [[0, 0, 0], [60, 0, 0]])
/// let wave = BezierPath3D(from: [0, 16, 12]) {
///     curve(controlX: 20, controlY: 34, controlZ: -4, controlX: 40, controlY: 0, controlZ: 26, endX: 60, endY: 16, endZ: 2)
/// }
///
/// RuledSurface(from: straight, to: wave)
///     .enclosed(offset: [0, 0, 1.5])
/// ```
///
/// On the surface, `u` runs along the curves and `v` runs across, from the first curve (`0`) to the second (`1`).
/// 2D curves are placed in the XY plane.
///
/// - SeeAlso: ``CoonsPatch``
///
public struct RuledSurface<First: ParametricCurve<Vector3D>, Second: ParametricCurve<Vector3D>>: ParametricSurface {
    let first: ArcLengthParameterization<First>
    let second: ArcLengthParameterization<Second>

    /// Creates a surface of straight lines between two curves.
    ///
    /// - Parameters:
    ///   - first: The curve at one edge of the surface.
    ///   - second: The curve at the opposite edge. Its start is joined to the start of `first`, and its end to
    ///     the end of `first`.
    ///
    public init<A: ParametricCurve, B: ParametricCurve>(from first: A, to second: B) where A.Curve3D == First, B.Curve3D == Second {
        self.first = ArcLengthParameterization(first.curve3D)
        self.second = ArcLengthParameterization(second.curve3D)
    }

    public func point(at uv: Vector2D) -> Vector3D {
        first.point(atFraction: uv.x).point(alongLineTo: second.point(atFraction: uv.x), at: uv.y)
    }
}
