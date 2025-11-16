import Foundation

public typealias BezierPath2D = BezierPath<Vector2D>
public typealias BezierPath3D = BezierPath<Vector3D>

/// A `BezierPath` represents a sequence of connected Bezier curves, forming a path.
///
/// You can create a `BezierPath` by providing a starting point and adding curves and line segments to the path. 2D
/// paths can be used to create `Polygon` shapes.
///
/// To create a `BezierPath`, start with the `init(startPoint:)` initializer, specifying the starting point of the path.
/// Then, you can chain calls to `addingLine(to:)`, `addingQuadraticCurve(controlPoint:end:)`, and
/// `addingCubicCurve(controlPoint1:controlPoint2:end:)` to build a complete path.
///
public struct BezierPath <V: Vector>: Sendable, Hashable, Codable {
    let startPoint: V
    let curves: [Curve]

    init(startPoint: V, curves: [Curve]) {
        self.startPoint = startPoint
        self.curves = curves
    }
}

public extension BezierPath {
    /// Initializes a new `BezierPath` starting at the given point.
    ///
    /// - Parameter startPoint: The starting point of the Bezier path.
    /// 
    init(startPoint: V) {
        self.init(startPoint: startPoint, curves: [])
    }

    /// Initializes a `BezierPath` with a sequence of straight lines between the given points.
    /// - Parameter points: An array of at least one point
    /// - Note: This initializer creates a linear Bezier path by connecting each pair of points with a straight line.
    ///
    init(linesBetween points: [V]) {
        precondition(!points.isEmpty, "At least one start point is required for Bezier paths")
        self.startPoint = points[0]
        self.curves = points.paired().map {
            Curve(controlPoints: [$0, $1])
        }
    }
}

extension BezierPath: CustomDebugStringConvertible {
    public var debugDescription: String {
        "Start point: \(startPoint)\n" + curves.enumerated().map { "\($0): " + $1.debugDescription }.joined(separator: "\n")
    }
}

extension BezierPath: ParametricCurve {
    /// A `Double` value that represents a fractional position along a Bézier path.
    /// The integer part of the value represents the index of the Bézier curve within the path,
    /// and the fractional part represents a position within that specific curve.
    ///
    /// For example:
    /// - `0.0` represents the start of the first curve.
    /// - `1.0` represents the start of the second curve.
    /// - `1.5` represents the midpoint of the second curve.
    ///
    public var domain: ClosedRange<Double> {
        0...Double(curves.count)
    }

    /// Returns the point at a specific fractional position along the path.
    ///
    /// - Parameter fraction: A fractional value indicating the position along the path.
    ///   The integer part indicates the curve index; the fractional part specifies the location within that curve.
    /// - Returns: The interpolated point along the path at the specified position.
    public func point(at fraction: Double) -> V {
        guard !isEmpty else { return startPoint }
        let (curveIndex, t) = curveIndexAndFraction(for: fraction)
        return curves[curveIndex].point(at: t)
    }

    /// Generates a sequence of points representing the path by sampling each curve.
    ///
    /// Straight line segments are represented minimally (start/end only); they are not subdivided.
    /// Use ``subdividedPoints(segmentation:)`` to subdivide straight segments as well.
    ///
    /// - Parameter segmentation: The desired level of detail for the generated points, affecting the smoothness of curves.
    /// - Returns: An array of points that approximate the Bézier path.
    /// - SeeAlso: ``subdividedPoints(segmentation:)``
    ///
    public func points(segmentation: Segmentation) -> [V] {
        [startPoint] + curves.flatMap {
            $0.points(segmentation: segmentation, subdividingStraightLines: false)
                .dropFirst(1).map(\.1)
        }
    }

    public var isEmpty: Bool {
        curves.isEmpty
    }

    public var sampleCountForLengthApproximation: Int { 10 }

    public func mapPoints(_ transformer: (V) -> Vector2D) -> BezierPath2D {
        map(transformer)
    }

    public func mapPoints(_ transformer: (V) -> Vector3D) -> BezierPath3D {
        map(transformer)
    }

    public var derivativeView: any CurveDerivativeView<V> {
        BezierPathDerivativeView(derivative: derivative)
    }

    public func points(in range: ClosedRange<Double>, segmentation: Segmentation) -> [V] {
        subpath(in: range).points(segmentation: segmentation)
    }

    public var labeledControlPoints: [(V, label: String?)]? {
        [(startPoint, "Start")] + curves.enumerated().flatMap { curveIndex, curve in
            curve.controlPoints.enumerated().dropFirst().map { controlPointIndex, controlPoint in
                (controlPoint, "c\(curveIndex)p\(controlPointIndex)")
            }
        }
    }
}

internal struct BezierPathDerivativeView<V: Vector>: CurveDerivativeView {
    let derivative: BezierPath<V>

    func tangent(at u: Double) -> Direction<V.D> {
        Direction(derivative.point(at: u))
    }
}

extension BezierPath: Transformable {
    /// Applies the given transform to the `BezierPath`.
    ///
    /// - Parameter transform: The affine transform to apply.
    /// - Returns: A new `BezierPath` instance with the transformed points.
    public func transformed(_ transform: V.D.Transform) -> BezierPath {
        BezierPath(
            startPoint: transform.apply(to: startPoint),
            curves: curves.map { $0.transformed(using: transform) }
        )
    }
}
