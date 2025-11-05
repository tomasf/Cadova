import Foundation

/// A curve evaluated by a single scalar parameter `u`.
///
/// - SeeAlso: `BezierPath`
///
public protocol ParametricCurve<V>: Sendable, Hashable, Codable {
    associatedtype V: Vector
    associatedtype Curve2D: ParametricCurve<Vector2D>
    associatedtype Curve3D: ParametricCurve<Vector3D>
    typealias Axis = V.D.Axis

    // add dpcs-does this curve represent an actual curve with a length? A bezier path without curves inside does not, for example.
    // A subcurve with the same lowerBound and upperBounds also does not
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

    // add docs
    func points(in range: ClosedRange<Double>, segmentation: Segmentation) -> [V]

    /// Solves for a parameter `u` whose point has the given coordinate value
    /// along an axis (only valid when the curve is monotone in that axis).
    ///
    /// - Parameters:
    ///   - value: Target coordinate value.
    ///   - axis:  Axis whose coordinate is matched.
    /// - Returns: The parameter `u` if a solution is found, otherwise `nil`.
    func parameter(matching value: Double, along axis: Axis) -> Double?

    /// Returns rich samples along the curve.
    ///
    /// - Note: The first sample’s `distance` must be `0`. Each
    ///   subsequent sample’s `distance` is the accumulated arc length
    ///   measured from that first sample (i.e., the start of this extraction),
    ///   not from the start of the curve’s domain.
    func samples(segmentation: Segmentation) -> [CurveSample<V>]

    // add docs. this is for efficently repeatedly evaluating tangents along the curve
    var derivativeView: any CurveDerivativeView<V> { get }

    /// Calculates the total length of the curve.
    ///
    /// - Parameter segmentation: The desired level of detail for the generated points, which influences the accuracy
    ///   of the length calculation. More detailed segmentation results in more points being generated, leading to a
    ///   more accurate length approximation.
    /// - Returns: A `Double` value representing the total length of the curve.
    /// 
    func length(segmentation: Segmentation) -> Double

    // get a subrange of the curve as a new curve
    subscript(range: any RangeExpression<Double>) -> Subcurve<Self> { get }

    // apply an operation to a curve's points
    func mapPoints(_ transformer: (V) -> Vector2D) -> Curve2D
    func mapPoints(_ transformer: (V) -> Vector3D) -> Curve3D

    var sampleCountForLengthApproximation: Int { get }

    var labeledControlPoints: [(V, label: String?)]? { get }
}

public protocol CurveDerivativeView<V> {
    associatedtype V: Vector
    func tangent(at u: Double) -> Direction<V.D>
}
