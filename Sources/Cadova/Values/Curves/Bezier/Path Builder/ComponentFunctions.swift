import Foundation

/// Creates a straight line segment to a specified point.
///
/// This generic function works with both 2D and 3D paths. The point is interpreted
/// according to the path's positioning mode (absolute or relative).
///
/// - Parameter point: The destination point for the line segment.
/// - Returns: A path component representing a straight line to the given point.
///
/// - SeeAlso: ``line(x:y:)`` for 2D paths with individual coordinate control.
/// - SeeAlso: ``line(x:y:z:)`` for 3D paths with individual coordinate control.
///
public func line<V: Vector>(_ point: V) -> BezierPath<V>.Component {
    .init([.init(point)])
}

/// Creates a line segment that continues in the direction of the previous segment.
///
/// This function extends the path in the same direction as the preceding curve's end tangent.
/// It is useful for creating smooth transitions where the path should continue straight
/// for a given distance before changing direction.
///
/// - Parameter distance: The length of the line segment to add.
/// - Returns: A path component representing a line continuing in the current direction.
///
/// - Precondition: The path must have at least one existing segment to determine the direction.
///
public func continuousLine<V: Vector>(distance: Double) -> BezierPath<V>.Component {
    .init(continuousDistance: distance, [])
}

/// Creates a Bezier curve segment with the specified control points.
///
/// The number of control points determines the curve order:
/// - 1 control point: Linear segment (equivalent to a line)
/// - 2 control points: Quadratic Bezier curve (one control point, one end point)
/// - 3 control points: Cubic Bezier curve (two control points, one end point)
///
/// The last point in the array is always the curve's end point. Points are interpreted
/// according to the path's positioning mode (absolute or relative).
///
/// - Parameter controlPoints: An array of control points defining the curve shape and end point.
/// - Returns: A path component representing a Bezier curve.
///
public func curve<V: Vector>(_ controlPoints: [V]) -> BezierPath<V>.Component {
    .init(controlPoints.map(PathBuilderVector<V>.init))
}

/// Creates a Bezier curve segment with the specified control points.
///
/// The number of control points determines the curve order:
/// - 1 control point: Linear segment (equivalent to a line)
/// - 2 control points: Quadratic Bezier curve (one control point, one end point)
/// - 3 control points: Cubic Bezier curve (two control points, one end point)
///
/// The last point is always the curve's end point. Points are interpreted
/// according to the path's positioning mode (absolute or relative).
///
/// - Parameter controlPoints: Variadic control points defining the curve shape and end point.
/// - Returns: A path component representing a Bezier curve.
///
public func curve<V: Vector>(_ controlPoints: V...) -> BezierPath<V>.Component {
    .init(controlPoints.map(PathBuilderVector<V>.init))
}

/// Creates a Bezier curve to `end`, with its control points given as handles relative to the points they belong to.
///
/// The `leaving` handle is an offset from the current point, and sets the direction the curve leaves in. The
/// `arriving` handle is an offset from `end`, and sets the direction the curve arrives from. Handles are always
/// relative to their own point; only `end` follows the path's positioning mode (absolute or relative).
///
/// - Parameters:
///   - end: The end point of the curve.
///   - leaving: The first control point, as an offset from the current point.
///   - arriving: The last control point, as an offset from `end`. Leave it out for a quadratic curve that only
///     has a leaving handle.
/// - Returns: A path component representing a Bezier curve.
///
/// - Example:
///   ```swift
///   let arm = BezierPath3D(from: armRoot) {
///       curve(to: armBend, leaving: [0, 20, 0], arriving: [0, 0, 8])
///       curve(to: ballCenter, leaving: [0, 0, -10], arriving: [0, -2, -12])
///   }
///   ```
///
public func curve<V: Vector>(to end: V, leaving: V, arriving: V? = nil) -> BezierPath<V>.Component {
    .init { path, mode in
        path.addingCurve(to: PathBuilderVector(end).value(relativeTo: path.endPoint, defaultMode: mode), leaving: leaving, arriving: arriving)
    }
}

/// Creates a Bezier curve to `end` that continues smoothly in the direction the path currently ends in.
///
/// The leaving handle points the same way as the end of the previous segment, with the given length, so the two
/// segments meet without a corner. The `arriving` handle is an offset from `end`. Only `end` follows the path's
/// positioning mode (absolute or relative).
///
/// - Parameters:
///   - end: The end point of the curve.
///   - leaving: The length of the leaving handle, along the direction the path currently ends in.
///   - arriving: The last control point, as an offset from `end`. Leave it out for a quadratic curve that only
///     has a leaving handle.
/// - Returns: A path component representing a smooth continuation curve.
///
/// - Example:
///   ```swift
///   let arm = BezierPath3D(from: armRoot) {
///       curve(to: armBend, leaving: [0, 20, 0], arriving: [0, 0, 8])
///       curve(to: ballCenter, leaving: 10, arriving: [0, -2, -12])
///   }
///   ```
///
/// - Precondition: The path must have at least one existing segment to determine the direction.
///
public func curve<V: Vector>(to end: V, leaving: Double, arriving: V? = nil) -> BezierPath<V>.Component {
    .init { path, mode in
        path.addingCurve(to: PathBuilderVector(end).value(relativeTo: path.endPoint, defaultMode: mode), leaving: leaving, arriving: arriving)
    }
}

/// Creates a quadratic Bezier curve to `end`, with its control point given as a handle relative to `end`.
///
/// The `arriving` handle is an offset from `end`, and sets the direction the curve arrives from. Only `end`
/// follows the path's positioning mode (absolute or relative).
///
/// - Parameters:
///   - end: The end point of the curve.
///   - arriving: The control point, as an offset from `end`.
/// - Returns: A path component representing a quadratic Bezier curve.
///
public func curve<V: Vector>(to end: V, arriving: V) -> BezierPath<V>.Component {
    .init { path, mode in
        path.addingCurve(to: PathBuilderVector(end).value(relativeTo: path.endPoint, defaultMode: mode), arriving: arriving)
    }
}

/// Creates a Bezier curve that continues smoothly from the previous segment.
///
/// This function creates a curve whose initial direction matches the end tangent of the
/// preceding segment, ensuring a smooth (C1 continuous) transition. The first control point
/// is automatically placed at the specified distance along the previous segment's direction.
///
/// - Parameters:
///   - distance: The distance from the current point to the first (implicit) control point,
///     placed along the direction of the previous segment's end tangent.
///   - controlPoints: Additional control points and the end point for the curve.
/// - Returns: A path component representing a smooth continuation curve.
///
/// - Precondition: The path must have at least one existing segment to determine the direction.
///
public func continuousCurve<V: Vector>(distance: Double, controlPoints: [V]) -> BezierPath<V>.Component {
    .init(continuousDistance: distance, controlPoints.map(PathBuilderVector<V>.init))
}
