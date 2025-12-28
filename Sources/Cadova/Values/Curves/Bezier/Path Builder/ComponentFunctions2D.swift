import Foundation

/// Creates a 2D line segment with individual coordinate control.
///
/// Each coordinate can be specified as:
/// - A raw `Double` value, interpreted according to the path's default positioning mode
/// - A value with explicit positioning using `.relative` or `.absolute` suffixes
/// - `.unchanged` to keep the coordinate at its current value
///
/// - Parameters:
///   - x: The X coordinate of the destination point. Defaults to `.unchanged`.
///   - y: The Y coordinate of the destination point. Defaults to `.unchanged`.
/// - Returns: A 2D path component representing a straight line.
///
/// - Example:
///   ```swift
///   BezierPath2D(from: [10, 4], mode: .relative) {
///       line(x: 22, y: 1)  // Move by (22, 1) relative to current point
///       line(x: 2)         // Move by (2, 0) keeping Y unchanged
///       line(y: 76)        // Move by (0, 76) keeping X unchanged
///   }
///   ```
///
public func line(
    x: any PathBuilderValue = .unchanged,
    y: any PathBuilderValue = .unchanged
) -> BezierPath2D.Component {
    .init([.init(x, y)])
}

/// Creates a 2D quadratic Bezier curve with one control point.
///
/// A quadratic Bezier curve is defined by the current point, one control point that
/// influences the curve's shape, and an end point. The curve is pulled toward the
/// control point but does not pass through it.
///
/// Each coordinate can be specified as a raw `Double`, with `.relative`/`.absolute` suffixes,
/// or as `.unchanged`.
///
/// - Parameters:
///   - x1: The X coordinate of the control point.
///   - y1: The Y coordinate of the control point.
///   - endX: The X coordinate of the end point.
///   - endY: The Y coordinate of the end point.
/// - Returns: A 2D path component representing a quadratic Bezier curve.
///
/// - Example:
///   ```swift
///   BezierPath2D(from: [0, 0]) {
///       curve(controlX: 50, controlY: 100, endX: 100, endY: 0)
///   }
///   ```
///
public func curve(
    controlX x1: any PathBuilderValue, controlY y1: any PathBuilderValue,
    endX: any PathBuilderValue, endY: any PathBuilderValue
) -> BezierPath2D.Component {
    .init([.init(x1, y1), .init(endX, endY)])
}

/// Creates a 2D quadratic Bezier curve that continues smoothly from the previous segment.
///
/// The curve's first control point is automatically placed along the previous segment's
/// end tangent direction, ensuring a smooth (C1 continuous) transition. This creates
/// a quadratic curve with the control point implicitly defined.
///
/// - Parameters:
///   - distance: The distance from the current point to the implicit control point,
///     placed along the previous segment's end tangent direction.
///   - endX: The X coordinate of the end point.
///   - endY: The Y coordinate of the end point.
/// - Returns: A 2D path component representing a smooth continuation curve.
///
/// - Precondition: The path must have at least one existing segment.
///
public func continuousCurve(
    distance: Double,
    endX: any PathBuilderValue, endY: any PathBuilderValue
) -> BezierPath2D.Component {
    .init(continuousDistance: distance, [.init(endX, endY)])
}

/// Creates a 2D cubic Bezier curve with two control points.
///
/// A cubic Bezier curve is defined by the current point, two control points that
/// shape the curve, and an end point. The curve is pulled toward both control points
/// but typically does not pass through them.
///
/// Cubic curves provide more flexibility than quadratic curves, allowing for
/// S-shaped curves and more complex paths.
///
/// Each coordinate can be specified as a raw `Double`, with `.relative`/`.absolute` suffixes,
/// or as `.unchanged`.
///
/// - Parameters:
///   - x1: The X coordinate of the first control point.
///   - y1: The Y coordinate of the first control point.
///   - x2: The X coordinate of the second control point.
///   - y2: The Y coordinate of the second control point.
///   - endX: The X coordinate of the end point.
///   - endY: The Y coordinate of the end point.
/// - Returns: A 2D path component representing a cubic Bezier curve.
///
/// - Example:
///   ```swift
///   BezierPath2D(from: [0, 0]) {
///       curve(
///           controlX: 25, controlY: 100,
///           controlX: 75, controlY: 100,
///           endX: 100, endY: 0
///       )
///   }
///   ```
///
public func curve(
    controlX x1: any PathBuilderValue, controlY y1: any PathBuilderValue,
    controlX x2: any PathBuilderValue, controlY y2: any PathBuilderValue,
    endX: any PathBuilderValue, endY: any PathBuilderValue
) -> BezierPath2D.Component {
    .init([.init(x1, y1), .init(x2, y2), .init(endX, endY)])
}

/// Creates a 2D cubic Bezier curve that continues smoothly from the previous segment.
///
/// The curve's first control point is automatically placed along the previous segment's
/// end tangent direction, ensuring a smooth (C1 continuous) transition. You specify only
/// the second control point and the end point.
///
/// - Parameters:
///   - distance: The distance from the current point to the first (implicit) control point,
///     placed along the previous segment's end tangent direction.
///   - x2: The X coordinate of the second control point.
///   - y2: The Y coordinate of the second control point.
///   - endX: The X coordinate of the end point.
///   - endY: The Y coordinate of the end point.
/// - Returns: A 2D path component representing a smooth continuation cubic curve.
///
/// - Precondition: The path must have at least one existing segment.
///
public func continuousCurve(
    distance: Double,
    controlX x2: any PathBuilderValue, controlY y2: any PathBuilderValue,
    endX: any PathBuilderValue, endY: any PathBuilderValue
) -> BezierPath2D.Component {
    .init(continuousDistance: distance, [.init(x2, y2), .init(endX, endY)])
}

internal func arc(center: PathBuilderVector<Vector2D>, angle: Angle, clockwise: Bool) -> BezierPath2D.Component {
    return .init { path, positioning in
        let absoluteCenter = center.value(relativeTo: path.endPoint, defaultMode: positioning)
        let absoluteAngle = positioning == .relative ? atan2(path.endPoint - absoluteCenter) + angle : angle
        return path.addingArc(center: absoluteCenter, to: absoluteAngle, clockwise: clockwise)
    }
}

/// Creates a clockwise arc around a center point, sweeping through the specified angle.
///
/// The arc starts at the current path position and sweeps clockwise around the given center
/// for the specified angular distance. The radius is determined by the distance from the
/// current point to the center.
///
/// When the path uses absolute positioning, the `angle` parameter specifies the absolute
/// end angle of the arc. When using relative positioning, it specifies how far to rotate
/// from the current position.
///
/// - Parameters:
///   - center: The center point of the arc.
///   - angle: The angle to sweep through (absolute or relative depending on path mode).
/// - Returns: A 2D path component representing a clockwise arc.
///
/// - SeeAlso: ``counterclockwiseArc(center:angle:)``
/// - SeeAlso: ``clockwiseArc(centerX:centerY:angle:)``
///
public func clockwiseArc(center: Vector2D, angle: Angle) -> BezierPath2D.Component {
    arc(center: .init(center), angle: angle, clockwise: true)
}

/// Creates a counterclockwise arc around a center point, sweeping through the specified angle.
///
/// The arc starts at the current path position and sweeps counterclockwise around the given
/// center for the specified angular distance. The radius is determined by the distance from
/// the current point to the center.
///
/// When the path uses absolute positioning, the `angle` parameter specifies the absolute
/// end angle of the arc. When using relative positioning, it specifies how far to rotate
/// from the current position.
///
/// - Parameters:
///   - center: The center point of the arc.
///   - angle: The angle to sweep through (absolute or relative depending on path mode).
/// - Returns: A 2D path component representing a counterclockwise arc.
///
/// - SeeAlso: ``clockwiseArc(center:angle:)``
/// - SeeAlso: ``counterclockwiseArc(centerX:centerY:angle:)``
///
public func counterclockwiseArc(center: Vector2D, angle: Angle) -> BezierPath2D.Component {
    arc(center: .init(center), angle: angle, clockwise: false)
}

/// Creates a clockwise arc with individual coordinate control for the center.
///
/// This variant allows specifying the center point using individual X and Y coordinates,
/// each of which can use different positioning modes or be left unchanged from the current
/// position.
///
/// - Parameters:
///   - centerX: The X coordinate of the arc's center. Defaults to `.unchanged`.
///   - centerY: The Y coordinate of the arc's center. Defaults to `.unchanged`.
///   - angle: The angle to sweep through.
/// - Returns: A 2D path component representing a clockwise arc.
///
/// - Example:
///   ```swift
///   BezierPath2D(from: [-5, 0], mode: .relative) {
///       line(y: 10)
///       clockwiseArc(centerX: 5, angle: 180°)  // Arc around point 5 units to the right
///       line(y: -10)
///   }
///   ```
///
/// - SeeAlso: ``clockwiseArc(center:angle:)``
///
public func clockwiseArc(
    centerX: any PathBuilderValue = .unchanged,
    centerY: any PathBuilderValue = .unchanged,
    angle: Angle
) -> BezierPath2D.Component {
    arc(center: .init(centerX, centerY), angle: angle, clockwise: true)
}

/// Creates a counterclockwise arc with individual coordinate control for the center.
///
/// This variant allows specifying the center point using individual X and Y coordinates,
/// each of which can use different positioning modes or be left unchanged from the current
/// position.
///
/// - Parameters:
///   - centerX: The X coordinate of the arc's center. Defaults to `.unchanged`.
///   - centerY: The Y coordinate of the arc's center. Defaults to `.unchanged`.
///   - angle: The angle to sweep through.
/// - Returns: A 2D path component representing a counterclockwise arc.
///
/// - SeeAlso: ``counterclockwiseArc(center:angle:)``
///
public func counterclockwiseArc(
    centerX: any PathBuilderValue = .unchanged,
    centerY: any PathBuilderValue = .unchanged,
    angle: Angle
) -> BezierPath2D.Component {
    arc(center: .init(centerX, centerY), angle: angle, clockwise: false)
}
