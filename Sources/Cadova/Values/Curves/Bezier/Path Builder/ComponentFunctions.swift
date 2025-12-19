import Foundation

// MARK: - Generic

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

// MARK: - 2D

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


// MARK: - 3D

/// Creates a 3D line segment with individual coordinate control.
///
/// Each coordinate can be specified as:
/// - A raw `Double` value, interpreted according to the path's default positioning mode
/// - A value with explicit positioning using `.relative` or `.absolute` suffixes
/// - `.unchanged` to keep the coordinate at its current value
///
/// - Parameters:
///   - x: The X coordinate of the destination point. Defaults to `.unchanged`.
///   - y: The Y coordinate of the destination point. Defaults to `.unchanged`.
///   - z: The Z coordinate of the destination point. Defaults to `.unchanged`.
/// - Returns: A 3D path component representing a straight line.
///
/// - Example:
///   ```swift
///   BezierPath3D(from: [0, 0, 0], mode: .relative) {
///       line(x: 10, y: 5, z: 2)  // Move by (10, 5, 2)
///       line(z: 10)              // Move up 10 units, keeping X and Y unchanged
///   }
///   ```
///
public func line(
    x: any PathBuilderValue = .unchanged,
    y: any PathBuilderValue = .unchanged,
    z: any PathBuilderValue = .unchanged
) -> BezierPath3D.Component {
    .init([.init(x, y, z)])
}

/// Creates a 3D quadratic Bezier curve with one control point.
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
///   - z1: The Z coordinate of the control point.
///   - endX: The X coordinate of the end point.
///   - endY: The Y coordinate of the end point.
///   - endZ: The Z coordinate of the end point.
/// - Returns: A 3D path component representing a quadratic Bezier curve.
///
public func curve(
    controlX x1: any PathBuilderValue, controlY y1: any PathBuilderValue, controlZ z1: any PathBuilderValue,
    endX: any PathBuilderValue, endY: any PathBuilderValue, endZ: any PathBuilderValue
) -> BezierPath3D.Component {
    .init([.init(x1, y1, z1), .init(endX, endY, endZ)])
}

/// Creates a 3D quadratic Bezier curve that continues smoothly from the previous segment.
///
/// The curve's first control point is automatically placed along the previous segment's
/// end tangent direction, ensuring a smooth (C1 continuous) transition.
///
/// - Parameters:
///   - distance: The distance from the current point to the implicit control point,
///     placed along the previous segment's end tangent direction.
///   - endX: The X coordinate of the end point.
///   - endY: The Y coordinate of the end point.
///   - endZ: The Z coordinate of the end point.
/// - Returns: A 3D path component representing a smooth continuation curve.
///
/// - Precondition: The path must have at least one existing segment.
///
public func continuousCurve(
    distance: Double,
    endX: any PathBuilderValue, endY: any PathBuilderValue, endZ: any PathBuilderValue
) -> BezierPath3D.Component {
    .init(continuousDistance: distance, [.init(endX, endY, endZ)])
}

/// Creates a 3D cubic Bezier curve with two control points.
///
/// A cubic Bezier curve is defined by the current point, two control points that
/// shape the curve, and an end point. Cubic curves provide more flexibility than
/// quadratic curves, allowing for S-shaped curves and more complex 3D paths.
///
/// Each coordinate can be specified as a raw `Double`, with `.relative`/`.absolute` suffixes,
/// or as `.unchanged`.
///
/// - Parameters:
///   - x1: The X coordinate of the first control point.
///   - y1: The Y coordinate of the first control point.
///   - z1: The Z coordinate of the first control point.
///   - x2: The X coordinate of the second control point.
///   - y2: The Y coordinate of the second control point.
///   - z2: The Z coordinate of the second control point.
///   - endX: The X coordinate of the end point.
///   - endY: The Y coordinate of the end point.
///   - endZ: The Z coordinate of the end point.
/// - Returns: A 3D path component representing a cubic Bezier curve.
///
public func curve(
    controlX x1: any PathBuilderValue, controlY y1: any PathBuilderValue, controlZ z1: any PathBuilderValue,
    controlX x2: any PathBuilderValue, controlY y2: any PathBuilderValue, controlZ z2: any PathBuilderValue,
    endX: any PathBuilderValue, endY: any PathBuilderValue, endZ: any PathBuilderValue
) -> BezierPath3D.Component {
    .init([.init(x1, y1, z1), .init(x2, y2, z2), .init(endX, endY, endZ)])
}

/// Creates a 3D cubic Bezier curve that continues smoothly from the previous segment.
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
///   - z2: The Z coordinate of the second control point.
///   - endX: The X coordinate of the end point.
///   - endY: The Y coordinate of the end point.
///   - endZ: The Z coordinate of the end point.
/// - Returns: A 3D path component representing a smooth continuation cubic curve.
///
/// - Precondition: The path must have at least one existing segment.
///
public func continuousCurve(
    distance: Double,
    controlX x2: any PathBuilderValue, controlY y2: any PathBuilderValue, controlZ z2: any PathBuilderValue,
    endX: any PathBuilderValue, endY: any PathBuilderValue, endZ: any PathBuilderValue
) -> BezierPath3D.Component {
    .init(continuousDistance: distance, [.init(x2, y2, z2), .init(endX, endY, endZ)])
}
