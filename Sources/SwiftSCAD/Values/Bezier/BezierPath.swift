import Foundation

public typealias BezierPath2D = BezierPath<Vector2D>
public typealias BezierPath3D = BezierPath<Vector3D>

/// A `BezierPath` represents a sequence of connected Bezier curves, forming a path.
///
/// You can create a `BezierPath` by providing a starting point and adding curves and line segments to the path. 2D paths can be used to create `Polygon` shapes.
///
/// To create a `BezierPath`, start with the `init(startPoint:)` initializer, specifying the starting point of the path. Then, you can chain calls to `addingLine(to:)`, `addingQuadraticCurve(controlPoint:end:)`, and `addingCubicCurve(controlPoint1:controlPoint2:end:)` to build a complete path.
public struct BezierPath <V: Vector>: Sendable {
    let startPoint: V
    let curves: [Curve]

    var endPoint: V {
        curves.last?.controlPoints.last ?? startPoint
    }

    init(startPoint: V, curves: [Curve]) {
        self.startPoint = startPoint
        self.curves = curves
    }

    func adding(curve: Curve) -> BezierPath {
        let newCurves = curves + [curve]
        return BezierPath(startPoint: startPoint, curves: newCurves)
    }

    func continuousControlPoint(distance: Double) -> V {
        guard let previousCurve = curves.last else {
            preconditionFailure("Adding a continuous segment requires a previous segment to match")
        }
        return endPoint + previousCurve.endDirection * distance
    }
}

public extension BezierPath {
    /// Initializes a new `BezierPath` starting at the given point.
    ///
    /// - Parameter startPoint: The starting point of the Bezier path.
    init(startPoint: V) {
        self.init(startPoint: startPoint, curves: [])
    }

    /// Initializes a `BezierPath` with a sequence of straight lines between the given points.
    /// - Parameter points: An array of at least one point
    /// - Note: This initializer creates a linear Bezier path by connecting each pair of points with a straight line.
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
