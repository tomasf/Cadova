import Foundation

public extension BezierPath {
    /// Adds a Bezier curve to the path using the specified control points. This method can be used to add curves with any number of control points beyond the basic line, quadratic, and cubic curves.
    ///
    /// - Parameter controlPoints: A variadic list of control points defining the Bezier curve.
    /// - Returns: A new `BezierPath` instance with the added Bezier curve.
    func addingCurve(_ controlPoints: V...) -> BezierPath {
        adding(curve: Curve(controlPoints: [endPoint] + controlPoints))
    }

    /// Adds a Bezier curve to the path using the specified control points. This method can be used to add curves with any number of control points beyond the basic line, quadratic, and cubic curves.
    ///
    /// - Parameter controlPoints: A list of control points defining the Bezier curve.
    /// - Returns: A new `BezierPath` instance with the added Bezier curve.
    func addingCurve(_ controlPoints: [V]) -> BezierPath {
        adding(curve: Curve(controlPoints: [endPoint] + controlPoints))
    }

    /// Adds a C1 continuous Bezier curve to the path, ensuring smooth transitions between curves.
    /// The first control point is positioned at a fixed direction from the last endpoint, with the specified distance allowing for control over the curve’s sharpness or smoothness.
    ///
    /// - Parameters:
    ///   - distance: The distance to place the first control point from the last endpoint in a fixed direction.
    ///   - controlPoints: A variadic list of additional control points for the Bezier curve.
    /// - Returns: A new `BezierPath` instance with the added C1 continuous curve.
    func addingContinuousCurve(distance: Double, controlPoints: V...) -> BezierPath {
        let matchingControlPoint = continuousControlPoint(distance: distance)
        return adding(curve: Curve(controlPoints: [endPoint, matchingControlPoint] + controlPoints))
    }

    /// Adds a line segment from the last point of the `BezierPath` to the specified point.
    ///
    /// - Parameter point: The end point of the line segment to add.
    /// - Returns: A new `BezierPath` instance with the added line segment.
    func addingLine(to point: V) -> BezierPath {
        adding(curve: Curve(controlPoints: [endPoint, point]))
    }

    /// Adds a C1 continuous line segment from the last point of the `BezierPath`, positioning the control point in a fixed direction with the specified distance for smooth transitions.
    ///
    /// - Parameter distance: The distance to place the control point from the last endpoint in a fixed direction.
    /// - Returns: A new `BezierPath` instance with the added C1 continuous line segment.
    func addingContinuousLine(distance: Double) -> BezierPath {
        let matchingControlPoint = continuousControlPoint(distance: distance)
        return adding(curve: Curve(controlPoints: [endPoint, matchingControlPoint]))
    }

    /// Adds a quadratic Bezier curve to the `BezierPath`.
    ///
    /// - Parameters:
    ///   - controlPoint: The control point of the quadratic Bezier curve.
    ///   - end: The end point of the quadratic Bezier curve.
    /// - Returns: A new `BezierPath` instance with the added quadratic Bezier curve.
    func addingQuadraticCurve(controlPoint: V, end: V) -> BezierPath {
        adding(curve: Curve(controlPoints: [endPoint, controlPoint, end]))
    }

    /// Adds a C1 continuous quadratic Bezier curve to the `BezierPath`, fixing the direction of the control point from the previous curve’s endpoint for a smooth transition.
    /// The control point is placed at a specified distance from the start of the curve.
    ///
    /// - Parameters:
    ///   - distance: The distance to place the control point from the start in a fixed direction.
    ///   - end: The endpoint of the quadratic Bezier curve.
    /// - Returns: A new `BezierPath` instance with the added C1 continuous quadratic Bezier curve.
    func addingContinuousQuadraticCurve(distance: Double, end: V) -> BezierPath {
        let matchingControlPoint = continuousControlPoint(distance: distance)
        return adding(curve: Curve(controlPoints: [endPoint, matchingControlPoint, end]))
    }

    /// Adds a cubic Bezier curve to the `BezierPath`.
    ///
    /// - Parameters:
    ///   - controlPoint1: The first control point of the cubic Bezier curve.
    ///   - controlPoint2: The second control point of the cubic Bezier curve.
    ///   - end: The end point of the cubic Bezier curve.
    /// - Returns: A new `BezierPath` instance with the added cubic Bezier curve.
    func addingCubicCurve(controlPoint1: V, controlPoint2: V, end: V) -> BezierPath {
        adding(curve: Curve(controlPoints: [endPoint, controlPoint1, controlPoint2, end]))
    }

    /// Adds a C1 continuous cubic Bezier curve to the `BezierPath`, aligning the first control point directionally for a smooth transition from the previous curve.
    /// The distance parameter controls the position of the first control point, and the second control point is user-defined.
    ///
    /// - Parameters:
    ///   - distance: The distance to place the first control point from the start point in a fixed direction.
    ///   - controlPoint2: The second control point of the cubic Bezier curve.
    ///   - end: The endpoint of the cubic Bezier curve.
    /// - Returns: A new `BezierPath` instance with the added C1 continuous cubic Bezier curve.
    func addingContinuousCubicCurve(distance: Double, controlPoint2: V, end: V) -> BezierPath {
        let matchingControlPoint = continuousControlPoint(distance: distance)
        return adding(curve: Curve(controlPoints: [endPoint, matchingControlPoint, controlPoint2, end]))
    }

    /// Closes the path by adding a line segment from the last point back to the starting point.
    /// This method is useful for creating closed shapes, where the start and end points are the same.
    /// - Returns: A new `BezierPath` instance representing the closed path.
    func closed() -> BezierPath {
        addingLine(to: startPoint)
    }
}
