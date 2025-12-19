import Foundation

/// A view into a portion of an existing parametric curve.
///
/// A subcurve references a base curve and restricts evaluation to a specific parameter range.
/// It preserves the original parameterization (does not remap to 0...1).
///
/// You typically create subcurves using the subscript operator on any ``ParametricCurve``:
/// ```swift
/// let fullCurve = BezierPath2D(...)
/// let firstHalf = fullCurve[0...0.5]
/// ```
///
public struct Subcurve<Base: ParametricCurve>: ParametricCurve {
    public typealias V = Base.V
    let base: Base

    /// The parameter range this subcurve covers.
    public let domain: ClosedRange<Double>

    public var isEmpty: Bool { domain.length > 0 }
    public func point(at u: Double) -> V { base.point(at: u) }
    public var derivativeView: any CurveDerivativeView<V> { base.derivativeView }
    public var sampleCountForLengthApproximation: Int { base.sampleCountForLengthApproximation }

    public func points(in range: ClosedRange<Double>, segmentation: Segmentation) -> [V] {
        base.points(in: range, segmentation: segmentation)
    }

    public func mapPoints(_ transformer: (V) -> Vector2D) -> Subcurve<Base.Curve2D> {
        .init(base: base.mapPoints(transformer), domain: domain)
    }

    public func mapPoints(_ transformer: (V) -> Vector3D) -> Subcurve<Base.Curve3D> {
        .init(base: base.mapPoints(transformer), domain: domain)
    }
}
