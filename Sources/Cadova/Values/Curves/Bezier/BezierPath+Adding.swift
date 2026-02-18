import Foundation

public extension BezierPath {
    /// Adds a Bezier curve to the path using the specified control points. This method can be used to add curves with
    /// any number of control points beyond the basic line, quadratic, and cubic curves.
    ///
    /// - Parameter controlPoints: A variadic list of control points defining the Bezier curve.
    /// - Returns: A new `BezierPath` instance with the added Bezier curve.
    func addingCurve(_ controlPoints: V...) -> BezierPath {
        adding(curve: Curve(controlPoints: [endPoint] + controlPoints))
    }

    /// Adds a Bezier curve to the path using the specified control points. This method can be used to add curves with
    /// any number of control points beyond the basic line, quadratic, and cubic curves.
    ///
    /// - Parameter controlPoints: A list of control points defining the Bezier curve.
    /// - Returns: A new `BezierPath` instance with the added Bezier curve.
    func addingCurve<Points: Sequence<V>>(_ controlPoints: Points) -> BezierPath {
        adding(curve: Curve(controlPoints: [endPoint] + controlPoints))
    }

    /// Adds a C1 continuous Bezier curve to the path, ensuring smooth transitions between curves.
    /// The first control point is positioned at a fixed direction from the last endpoint, with the specified distance
    /// allowing for control over the curve’s sharpness or smoothness.
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

    /// Adds a C1 continuous line segment from the last point of the `BezierPath`, positioning the control point in a
    /// fixed direction with the specified distance for smooth transitions.
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

    /// Adds a C1 continuous quadratic Bezier curve to the `BezierPath`, fixing the direction of the control point from
    /// the previous curve’s endpoint for a smooth transition. The control point is placed at a specified distance from
    /// the start of the curve.
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

    /// Adds a C1 continuous cubic Bezier curve to the `BezierPath`, aligning the first control point directionally for
    /// a smooth transition from the previous curve. The distance parameter controls the position of the first control
    /// point, and the second control point is user-defined.
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

public extension BezierPath2D {
    /// Appends a circular arc, inferring both the start angle and the radius from the current end point.
    ///
    /// The arc starts at the path’s current end point and sweeps on the circle centered at `center` with
    /// a constant radius. The sweep proceeds toward `to` in the direction indicated by `clockwise` and is
    /// approximated by one or more cubic Bézier segments (each no more than 90°).
    ///
    /// - Parameters:
    ///   - center: The circle center.
    ///   - endAngle: The absolute end angle (measured counter-clockwise from +X) to sweep to.
    ///   - clockwise: If `true`, sweeps clockwise; otherwise counter‑clockwise.
    /// - Returns: A new `BezierPath2D` with the arc appended.
    ///
    func addingArc(center: Vector2D, to endAngle: Angle, clockwise: Bool = false) -> BezierPath {
        // Infer radius and start angle from current endPoint
        let delta = endPoint - center
        let radius = delta.magnitude
        let startAngle: Angle = atan2(delta)
        guard radius > 0 else { return self }

        // Compute signed sweep toward the requested end angle using Angle arithmetic
        var sweep: Angle = endAngle - startAngle
        if clockwise {
            while sweep > 0° { sweep = sweep - 360° }
        } else {
            while sweep < 0° { sweep = sweep + 360° }
        }
        guard !sweep.isZero else { return self }

        var path = self
        // Split into <= 90° segments for a good cubic approximation
        let segmentCount = max(1, Int(ceil((abs(sweep) / 90°))))
        let segmentAngle: Angle = sweep / Double(segmentCount)

        var aStart: Angle = startAngle
        for _ in 0..<segmentCount {
            let aEnd = aStart + segmentAngle
            // Endpoints on the circle
            let P0 = Vector2D(x: center.x + radius * cos(aStart), y: center.y + radius * sin(aStart))
            let P3 = Vector2D(x: center.x + radius * cos(aEnd),   y: center.y + radius * sin(aEnd))
            // Unit tangents (CCW tangent)
            let T0 = Vector2D(x: -sin(aStart), y: cos(aStart))
            let T1 = Vector2D(x: -sin(aEnd), y: cos(aEnd))
            // Cubic control distance along tangent
            let t = (4.0 / 3.0) * tan(segmentAngle / 4.0)
            let P1 = P0 + T0 * (t * radius)
            let P2 = P3 - T1 * (t * radius)

            path = path.adding(curve: Curve(controlPoints: [P0, P1, P2, P3]))
            aStart = aEnd
        }
        return path
    }

}
