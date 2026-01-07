import Foundation

/// Specifies how a stroke is aligned relative to an open curve.
public enum CurveStrokeAlignment: Hashable, Sendable, Codable {
    /// The stroke is placed on the left side of the curve direction.
    case left

    /// The stroke is centered on the curve.
    case centered

    /// The stroke is placed on the right side of the curve direction.
    case right
}

public extension ParametricCurve where V == Vector2D {
    /// Converts the curve into a stroked 2D geometry with the specified width.
    ///
    /// The curve is sampled into a polyline and expanded into a filled stroke polygon.
    /// Join behavior respects the `miterLimit` environment value, and cap behavior respects the
    /// `lineCapStyle` environment value. For this stroke, the miter limit is applied as a multiple
    /// of the stroke width on the side being offset (half the width for centered strokes).
    ///
    /// - Parameters:
    ///   - width: The thickness of the stroke. Must be positive.
    ///   - alignment: How the stroke is positioned relative to the curve direction.
    ///   - style: The line join style for corners (e.g., `.round`, `.miter`, `.bevel`).
    /// - Returns: A new geometry representing the stroked outline of the curve.
    func stroked(
        width: Double,
        alignment: CurveStrokeAlignment = .centered,
        style: LineJoinStyle = .miter
    ) -> any Geometry2D {
        readEnvironment(\.scaledSegmentation, \.miterLimit, \.lineCapStyle) { segmentation, miterLimit, capStyle in
            CachedNode(
                name: "strokeCurve",
                parameters: self, width, alignment, style, capStyle, segmentation, miterLimit
            ) {
                guard width > 0 else { return Empty() }
                let sampledPoints = points(segmentation: segmentation)
                let outline = strokeOutline(
                    points: sampledPoints,
                    width: width,
                    alignment: alignment,
                    style: style,
                    capStyle: capStyle,
                    segmentation: segmentation,
                    miterLimit: miterLimit
                )
                guard outline.isEmpty == false else { return Empty() }
                return Polygon(outline)
            }
        }
    }
}

private func strokeOutline(
    points: [Vector2D],
    width: Double,
    alignment: CurveStrokeAlignment,
    style: LineJoinStyle,
    capStyle: LineCapStyle,
    segmentation: Segmentation,
    miterLimit: Double
) -> [Vector2D] {
    let epsilon = 1e-9
    let filteredPoints = deduplicated(points: points, tolerance: epsilon)
    guard filteredPoints.count >= 2 else { return [] }

    let halfWidth = width / 2.0
    let leftOffset: Double
    let rightOffset: Double
    switch alignment {
    case .centered:
        leftOffset = halfWidth
        rightOffset = halfWidth
    case .left:
        leftOffset = width
        rightOffset = 0
    case .right:
        leftOffset = 0
        rightOffset = width
    }

    var leftPoints = offsetPolyline(
        points: filteredPoints,
        offset: leftOffset,
        isLeft: true,
        style: style,
        segmentation: segmentation,
        miterLimit: miterLimit
    )
    var rightPoints = offsetPolyline(
        points: filteredPoints,
        offset: rightOffset,
        isLeft: false,
        style: style,
        segmentation: segmentation,
        miterLimit: miterLimit
    )
    guard leftPoints.isEmpty == false, rightPoints.isEmpty == false else { return [] }

    if capStyle == .square {
        let capExtension = max(leftOffset, rightOffset)
        if capExtension > 0 {
            let startDir = (filteredPoints[1] - filteredPoints[0]).normalized
            let endDir = (filteredPoints[filteredPoints.count - 1] - filteredPoints[filteredPoints.count - 2]).normalized
            let startShift = startDir * capExtension
            let endShift = endDir * capExtension
            leftPoints[0] -= startShift
            rightPoints[0] -= startShift
            leftPoints[leftPoints.count - 1] += endShift
            rightPoints[rightPoints.count - 1] += endShift
        }
    }

    var outline: [Vector2D] = []
    appendPoints(&outline, leftPoints, tolerance: epsilon)

    let leftEnd = leftPoints[leftPoints.count - 1]
    let rightEnd = rightPoints[rightPoints.count - 1]
    let leftStart = leftPoints[0]
    let rightStart = rightPoints[0]

    let canRoundCaps = capStyle == .round && abs(leftOffset - rightOffset) <= epsilon && leftOffset > 0
    if canRoundCaps {
        let endCenter = filteredPoints[filteredPoints.count - 1]
        let endArc = arcPoints(
            center: endCenter,
            radius: leftOffset,
            startAngle: atan2(leftEnd - endCenter),
            endAngle: atan2(rightEnd - endCenter),
            clockwise: true,
            segmentation: segmentation
        )
        appendPoints(&outline, Array(endArc.dropFirst()), tolerance: epsilon)
    } else {
        appendIfDistinct(&outline, rightEnd, tolerance: epsilon)
    }

    appendPoints(&outline, Array(rightPoints.reversed().dropFirst()), tolerance: epsilon)

    if canRoundCaps {
        let startCenter = filteredPoints[0]
        let startArc = arcPoints(
            center: startCenter,
            radius: leftOffset,
            startAngle: atan2(rightStart - startCenter),
            endAngle: atan2(leftStart - startCenter),
            clockwise: true,
            segmentation: segmentation
        )
        appendPoints(&outline, Array(startArc.dropFirst()), tolerance: epsilon)
    } else {
        appendIfDistinct(&outline, leftStart, tolerance: epsilon)
    }

    return outline
}

private func offsetPolyline(
    points: [Vector2D],
    offset: Double,
    isLeft: Bool,
    style: LineJoinStyle,
    segmentation: Segmentation,
    miterLimit: Double
) -> [Vector2D] {
    let epsilon = 1e-9
    guard offset > 0 else { return points }

    let segmentCount = points.count - 1
    var directions: [Vector2D] = []
    var normals: [Vector2D] = []
    directions.reserveCapacity(segmentCount)
    normals.reserveCapacity(segmentCount)

    for i in 0..<segmentCount {
        let delta = points[i + 1] - points[i]
        let dir = Direction2D(delta).unitVector
        let normal = isLeft ? Direction2D(dir).counterclockwiseNormal.unitVector : Direction2D(dir).clockwiseNormal.unitVector
        directions.append(dir)
        normals.append(normal)
    }

    var result: [Vector2D] = []
    appendIfDistinct(&result, points[0] + normals[0] * offset, tolerance: epsilon)

    for i in 1..<(points.count - 1) {
        let prevDir = directions[i - 1]
        let nextDir = directions[i]
        let cross = prevDir × nextDir
        let prevNormal = normals[i - 1]
        let nextNormal = normals[i]
        let prevOffsetPoint = points[i] + prevNormal * offset
        let nextOffsetPoint = points[i] + nextNormal * offset

        if abs(cross) <= epsilon {
            appendIfDistinct(&result, prevOffsetPoint, tolerance: epsilon)
            continue
        }

        let isOuter = isLeft ? cross < 0 : cross > 0
        let prevLine = Line(point: prevOffsetPoint, direction: Direction2D(prevDir))
        let nextLine = Line(point: nextOffsetPoint, direction: Direction2D(nextDir))
        let intersection = prevLine.intersection(with: nextLine)

        if isOuter == false {
            if let intersection {
                appendIfDistinct(&result, intersection, tolerance: epsilon)
            } else {
                appendIfDistinct(&result, prevOffsetPoint, tolerance: epsilon)
            }
            continue
        }

        switch style {
        case .miter:
            if let intersection {
                if (intersection - points[i]).magnitude <= miterLimit * offset {
                    appendIfDistinct(&result, intersection, tolerance: epsilon)
                } else {
                    appendIfDistinct(&result, prevOffsetPoint, tolerance: epsilon)
                    appendIfDistinct(&result, nextOffsetPoint, tolerance: epsilon)
                }
            } else {
                appendIfDistinct(&result, prevOffsetPoint, tolerance: epsilon)
            }

        case .bevel, .square:
            appendIfDistinct(&result, prevOffsetPoint, tolerance: epsilon)
            appendIfDistinct(&result, nextOffsetPoint, tolerance: epsilon)

        case .round:
            let arc = arcPointsShortest(
                center: points[i],
                radius: offset,
                startAngle: atan2(prevOffsetPoint - points[i]),
                endAngle: atan2(nextOffsetPoint - points[i]),
                segmentation: segmentation
            )
            appendPoints(&result, Array(arc.dropFirst()), tolerance: epsilon)
        }
    }

    appendIfDistinct(&result, points[points.count - 1] + normals[segmentCount - 1] * offset, tolerance: epsilon)
    return result
}

private func arcPoints(
    center: Vector2D,
    radius: Double,
    startAngle: Angle,
    endAngle: Angle,
    clockwise: Bool,
    segmentation: Segmentation
) -> [Vector2D] {
    var sweep = endAngle - startAngle
    if clockwise {
        while sweep > 0° { sweep = sweep - 360° }
    } else {
        while sweep < 0° { sweep = sweep + 360° }
    }

    let count = max(segmentation.segmentCount(arcRadius: radius, angle: abs(sweep)), 2)
    return (0...count).map { index in
        let t = Double(index) / Double(count)
        let angle = startAngle + sweep * t
        return center + Vector2D(cos(angle), sin(angle)) * radius
    }
}

private func arcPointsShortest(
    center: Vector2D,
    radius: Double,
    startAngle: Angle,
    endAngle: Angle,
    segmentation: Segmentation
) -> [Vector2D] {
    let sweep = (endAngle - startAngle).normalized
    let count = max(segmentation.segmentCount(arcRadius: radius, angle: abs(sweep)), 2)
    return (0...count).map { index in
        let t = Double(index) / Double(count)
        let angle = startAngle + sweep * t
        return center + Vector2D(cos(angle), sin(angle)) * radius
    }
}

private func appendPoints(_ target: inout [Vector2D], _ points: [Vector2D], tolerance: Double) {
    for point in points {
        appendIfDistinct(&target, point, tolerance: tolerance)
    }
}

private func appendIfDistinct(_ target: inout [Vector2D], _ point: Vector2D, tolerance: Double) {
    guard let last = target.last else {
        target.append(point)
        return
    }
    if (last - point).magnitude > tolerance {
        target.append(point)
    }
}

private func deduplicated(points: [Vector2D], tolerance: Double) -> [Vector2D] {
    var result: [Vector2D] = []
    result.reserveCapacity(points.count)
    for point in points {
        if let last = result.last, (last - point).magnitude <= tolerance {
            continue
        }
        result.append(point)
    }
    return result
}
