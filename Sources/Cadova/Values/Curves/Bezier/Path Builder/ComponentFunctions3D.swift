import Foundation

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
