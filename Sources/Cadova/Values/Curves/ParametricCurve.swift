import Foundation

/// A parametric curve evaluated by a single scalar parameter `u`.
///
/// Conforming types represent geometric curves that can be sampled, measured,
/// and converted to 2D or 3D vector spaces. Unless otherwise specified, `u` grows
/// in the curve's "forward" direction and the curve is considered defined over
/// its `domain`.
///
/// - Notes:
///   - Implementations may choose to clamp, extrapolate, or otherwise define behavior
///     for parameter values outside of `domain`. Each conformer should document its policy.
///   - Some curves can be "empty" (e.g., a subcurve whose bounds collapse to a single value,
///     or a degenerate curve with zero length). See `isEmpty`.
///   - Tangent directions are provided via `derivativeView` for efficient repeated evaluation.
/// - SeeAlso: `SplineCurve`, `Subcurve`, `CurveSample`, `Segmentation`
public protocol ParametricCurve<V>: Sendable, Hashable, Codable {
    associatedtype V: Vector
    associatedtype Curve2D: ParametricCurve<Vector2D>
    associatedtype Curve3D: ParametricCurve<Vector3D>
    typealias Axis = V.D.Axis

    /// Indicates whether this curve represents a non‑trivial geometric curve.
    ///
    /// Implementations should return `true` when the curve has no measurable extent
    /// (for example, a subcurve whose lower and upper bounds are equal, or a curve
    /// with zero length/degenerate data) and `false` otherwise.
    var isEmpty: Bool { get }

    /// The parameter interval over which the curve is naturally defined.
    ///
    /// Conformers may clamp or extrapolate outside this range. Callers should not
    /// assume any particular behavior for out‑of‑range values unless the conformer’s
    /// documentation specifies it.
    var domain: ClosedRange<Double> { get }

    /// Evaluates the curve position at parameter `u`.
    ///
    /// - Parameter u: The parameter value. Values outside `domain` are permitted, but
    ///   behavior is curve‑specific (e.g., clamp, extrapolate, or mirror).
    /// - Returns: The point on the curve corresponding to `u`.
    func point(at u: Double) -> V

    /// Returns a set of points sampled along the entire curve.
    ///
    /// - Parameter segmentation: Controls the sampling density and strategy (fixed or adaptive).
    /// - Returns: An ordered array of points from start to end of `domain`. The first point
    ///   corresponds to `domain.lowerBound`, and the last to `domain.upperBound`.
    ///
    /// - SeeAlso: `points(in:segmentation:)`, `Segmentation`
    func points(segmentation: Segmentation) -> [V]

    /// Returns a set of points sampled along a parameter subrange.
    ///
    /// - Parameters:
    ///   - range: The parameter subrange to sample. Implementations should clamp this
    ///     range to `domain`. If the clamped range is empty, the result may be empty or
    ///     contain a single point, depending on the conformer.
    ///   - segmentation: Controls the sampling density and strategy (fixed or adaptive).
    /// - Returns: An ordered array of points covering `range ∩ domain`.
    func points(in range: ClosedRange<Double>, segmentation: Segmentation) -> [V]

    /// Solves for a parameter `u` whose point’s coordinate matches `value` along an axis.
    ///
    /// This method is only valid when the curve is monotone in the given axis over the
    /// relevant interval. If the curve is not monotone or no solution exists, `nil` is returned.
    ///
    /// - Parameters:
    ///   - value: The target coordinate value to match.
    ///   - axis: The axis whose coordinate is matched.
    /// - Returns: A parameter `u` such that `point(at: u)[axis] == value`, if found; otherwise `nil`.
    ///   Implementations may return a `u` outside `domain` if extrapolation is supported.
    func parameter(matching value: Double, along axis: Axis) -> Double?

    /// Returns rich samples along the curve suitable for framing, length accumulation, and analysis.
    ///
    /// The returned array must be ordered by increasing `u`. The first sample’s `distance` must be `0`.
    /// Each subsequent sample’s `distance` is the accumulated arc length measured from that first sample
    /// (i.e., the start of this extraction), not from the start of the curve’s overall `domain`.
    ///
    /// - Parameter segmentation: Controls the sampling density and strategy (fixed or adaptive).
    /// - Returns: An array of `CurveSample` values including parameter `u`, position, unit tangent
    ///   direction, and accumulated distance from the first sample.
    func samples(segmentation: Segmentation) -> [CurveSample<V>]

    /// Provides efficient access to curve derivatives for repeated tangent evaluation.
    ///
    /// This view is intended to avoid recomputing derivative structures when querying
    /// tangents at many parameter values. The returned tangents should be unit directions,
    /// or at minimum consistent with `Direction` semantics for the vector space.
    var derivativeView: any CurveDerivativeView<V> { get }

    /// Approximates the total arc length of the curve.
    ///
    /// - Parameter segmentation: The desired level of detail for the generated points,
    ///   which influences the accuracy of the length calculation. More detailed segmentation
    ///   produces a more accurate approximation at the cost of performance.
    /// - Returns: The approximate arc length of the curve over `domain`.
    func length(segmentation: Segmentation) -> Double

    /// Extracts a subcurve defined by a parameter range.
    ///
    /// The resulting subcurve preserves the original parameterization (i.e., it does not
    /// reparameterize to a normalized 0…1 range) and usually clamps the requested range to `domain`.
    ///
    /// - Parameter range: Any `RangeExpression` over `Double` describing the desired subrange.
    /// - Returns: A `Subcurve` view over the base curve. If the resulting range is empty,
    ///   the subcurve may be empty (see `isEmpty`).
    subscript(range: any RangeExpression<Double>) -> Subcurve<Self> { get }

    /// Creates a 2D curve by transforming each point of this curve.
    ///
    /// - Parameter transformer: A function that maps a point in `V` to `Vector2D`.
    /// - Returns: A new curve of type `Curve2D` with transformed points and equivalent parameterization.
    func mapPoints(_ transformer: (V) -> Vector2D) -> Curve2D

    /// Creates a 3D curve by transforming each point of this curve.
    ///
    /// - Parameter transformer: A function that maps a point in `V` to `Vector3D`.
    /// - Returns: A new curve of type `Curve3D` with transformed points and equivalent parameterization.
    func mapPoints(_ transformer: (V) -> Vector3D) -> Curve3D

    /// A hint for coarse length approximations or preview sampling.
    ///
    /// Conformers may return a representative sample count that callers can use to balance
    /// performance and quality when an explicit `Segmentation` is not available. This value
    /// is not a strict requirement and may be ignored by clients with their own strategies.
    var sampleCountForLengthApproximation: Int { get }

    /// Optional set of labeled control points for UI/inspection.
    ///
    /// When available, this provides the underlying control vertices used to define the curve,
    /// along with optional labels (e.g., indices or weights). Curves that are not control‑point‑based
    /// may return `nil`.
    var labeledControlPoints: [(V, label: String?)]? { get }
}

/// A lightweight interface for evaluating derivatives of a parametric curve.
///
/// Implementations should return tangent directions consistent with the parent curve’s
/// parameterization. Unless documented otherwise, `tangent(at:)` should produce a unit
/// direction or a value compatible with `Direction` semantics.
///
/// - SeeAlso: `ParametricCurve.derivativeView`
public protocol CurveDerivativeView<V> {
    associatedtype V: Vector

    /// Returns the tangent direction at parameter `u`.
    ///
    /// Implementations should define behavior for values outside the curve’s `domain`
    /// (e.g., clamp or extrapolate) consistent with the parent curve.
    func tangent(at u: Double) -> Direction<V.D>
}
