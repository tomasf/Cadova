import Foundation

/// A structured sample of a parametric curve at a specific parameter value.
public struct CurveSample<V: Vector>: Sendable, Hashable, Codable {
    /// The parameter value at which this sample was taken.
    public let u: Double
    /// The position on the curve.
    public let position: V
    /// The unit tangent direction at `u`.
    public let tangent: Direction<V.D>
    /// The accumulated arc length from the first sample in the current extraction up to `u`.
    public let distance: Double

    public init(u: Double, position: V, tangent: Direction<V.D>, distance: Double) {
        self.u = u
        self.position = position
        self.tangent = tangent
        self.distance = distance
    }

    func interpolated(with other: CurveSample, fraction: Double) -> Self {
        Self(
            u: u + (other.u - u) * fraction,
            position: position.point(alongLineTo: other.position, at: fraction),
            tangent: Direction(tangent.unitVector + (other.tangent.unitVector - tangent.unitVector) * fraction),
            distance: distance + (other.distance - distance) * fraction,
        )
    }
}
