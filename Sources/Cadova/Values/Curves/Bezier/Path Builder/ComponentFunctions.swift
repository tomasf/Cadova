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
