import Foundation

/// A curve evaluated by a single scalar parameter `u`.
///
/// - SeeAlso: `BezierPath`
///
public protocol ParametricCurve<V>: Sendable, Hashable, Codable {
    associatedtype V: Vector
    typealias Axis = V.D.Axis

    var isEmpty: Bool { get }

    /// The parameter interval over which the curve is naturally defined.
    ///
    /// - Note: Conformers may choose to extrapolate outside this range.
    var domain: ClosedRange<Double> { get }

    /// Returns the point at parameter `u`.
    ///
    /// - Parameter u: The parameter value. Values outside `domain` are allowed;
    ///   behavior (clamp/extrapolate/wrap) is curve-specific.
    func point(at u: Double) -> V

    /// Returns a set of points sampled along the curve.
    ///
    /// - Parameter segmentation: Controls sampling density.
    func points(segmentation: Segmentation) -> [V]

    /// Solves for a parameter `u` whose point has the given coordinate value
    /// along an axis (only valid when the curve is monotone in that axis).
    ///
    /// - Parameters:
    ///   - value: Target coordinate value.
    ///   - axis:  Axis whose coordinate is matched.
    /// - Returns: The parameter `u` if a solution is found, otherwise `nil`.
    func parameter(matching value: Double, along axis: Axis) -> Double?

    /// Returns a rich sample (position, tangent, accumulated arc length, etc.)
    /// at parameter `u`. The returned sample’s `distance` is `0`.
    func sample(at u: Double) -> CurveSample<V>

    /// Returns rich samples along the curve.
    ///
    /// - Note: The first sample’s `arcLengthFromStart` must be `0`. Each
    ///   subsequent sample’s `arcLengthFromStart` is the accumulated arc length
    ///   measured from that first sample (i.e., the start of this extraction),
    ///   not from the start of the curve’s domain.
    func samples(segmentation: Segmentation) -> [CurveSample<V>]

    var derivativeView: any CurveDerivativeView<V> { get }

    func length(in range: ClosedRange<Double>?, segmentation: Segmentation) -> Double

    func mapPoints<Output: Vector>(_ transformer: (V) -> Output) -> any ParametricCurve<Output>

    var sampleCountForLengthApproximation: Int { get }
}

public protocol CurveDerivativeView<V> {
    associatedtype V: Vector
    func tangent(at u: Double) -> Direction<V.D>
}

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

internal extension ParametricCurve {
    var curve3D: any ParametricCurve<Vector3D> {
        mapPoints(\.vector3D)
    }
}
