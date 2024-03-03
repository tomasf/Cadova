import Foundation

public typealias BezierPath2D = BezierPath<Vector2D>
public typealias BezierPath3D = BezierPath<Vector3D>

/// A `BezierPath` represents a sequence of connected Bezier curves, forming a path.
///
/// You can create a `BezierPath` by providing a starting point and adding curves and line segments to the path. 2D paths can be used to create `Polygon` shapes.
///
/// To create a `BezierPath`, start with the `init(startPoint:)` initializer, specifying the starting point of the path. Then, you can chain calls to `addingLine(to:)`, `addingQuadraticCurve(controlPoint:end:)`, and `addingCubicCurve(controlPoint1:controlPoint2:end:)` to build a complete path.
public struct BezierPath <V: Vector> {
    let startPoint: V
    let curves: [BezierCurve<V>]

    var endPoint: V {
        curves.last?.controlPoints.last ?? startPoint
    }

    private init(startPoint: V, curves: [BezierCurve<V>]) {
        self.startPoint = startPoint
        self.curves = curves
    }

    /// Initializes a new `BezierPath` starting at the given point.
    ///
    /// - Parameter startPoint: The starting point of the Bezier path.
    public init(startPoint: V) {
        self.init(startPoint: startPoint, curves: [])
    }

    /// Initializes a `BezierPath` with a sequence of straight lines between the given points.
    /// - Parameter points: An array of at least one point
    /// - Note: This initializer creates a linear Bezier path by connecting each pair of points with a straight line.
    public init(linesBetween points: [V]) {
        precondition(!points.isEmpty, "At least one start point is required for Bezier paths")
        self.startPoint = points[0]
        self.curves = points.paired().map {
            BezierCurve(controlPoints: [$0, $1])
        }
    }

    func adding(curve: BezierCurve<V>) -> BezierPath {
        let newCurves = curves + [curve]
        return BezierPath(startPoint: startPoint, curves: newCurves)
    }

    /// Adds a line segment from the last point of the `BezierPath` to the specified point.
    ///
    /// - Parameter point: The end point of the line segment to add.
    /// - Returns: A new `BezierPath` instance with the added line segment.
    public func addingLine(to point: V) -> BezierPath {
        adding(curve: BezierCurve(controlPoints: [endPoint, point]))
    }

    /// Adds a quadratic Bezier curve to the `BezierPath`.
    ///
    /// - Parameters:
    ///   - controlPoint: The control point of the quadratic Bezier curve.
    ///   - end: The end point of the quadratic Bezier curve.
    /// - Returns: A new `BezierPath` instance with the added quadratic Bezier curve.
    public func addingQuadraticCurve(controlPoint: V, end: V) -> BezierPath {
        adding(curve: BezierCurve(controlPoints: [endPoint, controlPoint, end]))
    }

    /// Adds a cubic Bezier curve to the `BezierPath`.
    ///
    /// - Parameters:
    ///   - controlPoint1: The first control point of the cubic Bezier curve.
    ///   - controlPoint2: The second control point of the cubic Bezier curve.
    ///   - end: The end point of the cubic Bezier curve.
    /// - Returns: A new `BezierPath` instance with the added cubic Bezier curve.
    public func addingCubicCurve(controlPoint1: V, controlPoint2: V, end: V) -> BezierPath {
        adding(curve: BezierCurve(controlPoints: [endPoint, controlPoint1, controlPoint2, end]))
    }

    /// Adds a Bezier curve to the path using the specified control points. This method can be used to add curves with any number of control points beyond the basic line, quadratic, and cubic curves.
    ///
    /// - Parameter controlPoints: A variadic list of control points defining the Bezier curve.
    /// - Returns: A new `BezierPath` instance with the added Bezier curve.
    public func addingCurve(_ controlPoints: V...) -> BezierPath {
        adding(curve: BezierCurve(controlPoints: controlPoints))
    }

    /// Closes the path by adding a line segment from the last point back to the starting point.
    /// This method is useful for creating closed shapes, where the start and end points are the same.
    /// - Returns: A new `BezierPath` instance representing the closed path.
    public func closed() -> BezierPath {
        addingLine(to: startPoint)
    }

    /// Generates a sequence of points representing the path.
    ///
    /// - Parameter facets: The desired level of detail for the generated points, affecting the smoothness of curves.
    /// - Returns: An array of points that approximate the Bezier path.
    public func points(facets: Environment.Facets) -> [V] {
        return [startPoint] + curves.map { curve in
            Array(curve.points(facets: facets)[1...])
        }.joined()
    }

    /// Applies the given 2D affine transform to the `BezierPath`.
    ///
    /// - Parameter transform: The affine transform to apply.
    /// - Returns: A new `BezierPath` instance with the transformed points.
    public func transform<T: AffineTransform>(using transform: T) -> BezierPath where T.Vector == V, T == V.Transform {
        BezierPath(
            startPoint: transform.apply(to: startPoint),
            curves: curves.map { $0.transform(using: transform) }
        )
    }
}
