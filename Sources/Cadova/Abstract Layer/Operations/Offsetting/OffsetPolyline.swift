import Foundation

public extension ParametricCurve where V == Vector2D {
    /// Offsets the curve by a specified distance, returning the result as a new path.
    ///
    /// The curve is sampled into a polyline and each segment is offset perpendicular to its direction.
    /// Join behavior at corners is controlled by the `style` parameter, and respects the `miterLimit`
    /// environment value when using `.miter` style.
    ///
    /// - Parameters:
    ///   - distance: The offset distance. Positive values offset to the left of the curve direction.
    ///   - style: The line join style for corners (e.g., `.round`, `.miter`, `.bevel`).
    /// - Returns: A new curve representing the offset path as straight line segments.
    func offset(by distance: Double, style: LineJoinStyle = .miter) -> any ParametricCurve<Vector2D> {
        @Environment(\.scaledSegmentation) var segmentation
        @Environment(\.miterLimit) var miterLimit

        let points = self.points(segmentation: segmentation)
        let offsetPoints = offsetPolyline(
            points: points,
            offset: distance,
            style: style,
            segmentation: segmentation,
            miterLimit: miterLimit
        )
        return BezierPath2D(linesBetween: offsetPoints)
    }
}

internal func offsetPolyline(
    points: [Vector2D],
    offset: Double,
    style: LineJoinStyle,
    segmentation: Segmentation,
    miterLimit: Double
) -> [Vector2D] {
    let epsilon = 1e-9
    let isLeft = offset > 0
    let absOffset = abs(offset)

    guard absOffset > 0 else { return points }

    let filteredPoints = deduplicated(points: points, tolerance: epsilon)
    guard filteredPoints.count >= 2 else { return filteredPoints }

    let (directions, normals) = polylineVectors(points: filteredPoints, isLeft: isLeft)

    var result: [Vector2D] = []
    appendIfDistinct(&result, filteredPoints[0] + normals[0].unitVector * absOffset, tolerance: epsilon)

    for i in 1..<(filteredPoints.count - 1) {
        let prevDir = directions[i - 1]
        let nextDir = directions[i]
        let cross = prevDir.unitVector × nextDir.unitVector
        let prevNormal = normals[i - 1]
        let nextNormal = normals[i]
        let prevOffsetPoint = filteredPoints[i] + prevNormal.unitVector * absOffset
        let nextOffsetPoint = filteredPoints[i] + nextNormal.unitVector * absOffset

        if abs(cross) <= epsilon {
            appendIfDistinct(&result, prevOffsetPoint, tolerance: epsilon)
            continue
        }

        let isOuter = isLeft ? cross < 0 : cross > 0
        let prevLine = Line(point: prevOffsetPoint, direction: prevDir)
        let nextLine = Line(point: nextOffsetPoint, direction: nextDir)
        let intersection = prevLine.intersection(with: nextLine)

        if isOuter == false {
            appendInnerJoin(
                result: &result,
                intersection: intersection,
                fallback: prevOffsetPoint,
                tolerance: epsilon
            )
            continue
        }

        appendOuterJoin(
            result: &result,
            intersection: intersection,
            prevOffsetPoint: prevOffsetPoint,
            nextOffsetPoint: nextOffsetPoint,
            prevDir: prevDir,
            nextDir: nextDir,
            center: filteredPoints[i],
            offset: absOffset,
            style: style,
            segmentation: segmentation,
            miterLimit: miterLimit,
            tolerance: epsilon
        )
    }

    let lastIndex = directions.count - 1
    appendIfDistinct(&result, filteredPoints[filteredPoints.count - 1] + normals[lastIndex].unitVector * absOffset, tolerance: epsilon)
    return result
}

internal func polylineVectors(
    points: [Vector2D],
    isLeft: Bool
) -> (directions: [Direction2D], normals: [Direction2D]) {
    let segmentCount = points.count - 1
    var directions: [Direction2D] = []
    var normals: [Direction2D] = []
    directions.reserveCapacity(segmentCount)
    normals.reserveCapacity(segmentCount)

    for i in 0..<segmentCount {
        let direction = Direction2D(points[i + 1] - points[i])
        let normal = isLeft ? direction.counterclockwiseNormal : direction.clockwiseNormal
        directions.append(direction)
        normals.append(normal)
    }

    return (directions, normals)
}

private func appendInnerJoin(
    result: inout [Vector2D],
    intersection: Vector2D?,
    fallback: Vector2D,
    tolerance: Double
) {
    if let intersection {
        appendIfDistinct(&result, intersection, tolerance: tolerance)
    } else {
        appendIfDistinct(&result, fallback, tolerance: tolerance)
    }
}

private func appendOuterJoin(
    result: inout [Vector2D],
    intersection: Vector2D?,
    prevOffsetPoint: Vector2D,
    nextOffsetPoint: Vector2D,
    prevDir: Direction2D,
    nextDir: Direction2D,
    center: Vector2D,
    offset: Double,
    style: LineJoinStyle,
    segmentation: Segmentation,
    miterLimit: Double,
    tolerance: Double
) {
    switch style {
    case .miter:
        if let intersection {
            if (intersection - center).magnitude <= miterLimit * offset {
                appendIfDistinct(&result, intersection, tolerance: tolerance)
            } else {
                appendIfDistinct(&result, prevOffsetPoint, tolerance: tolerance)
                appendIfDistinct(&result, nextOffsetPoint, tolerance: tolerance)
            }
        } else {
            appendIfDistinct(&result, prevOffsetPoint, tolerance: tolerance)
        }

    case .bevel:
        appendIfDistinct(&result, prevOffsetPoint, tolerance: tolerance)
        appendIfDistinct(&result, nextOffsetPoint, tolerance: tolerance)

    case .square:
        let bisector = Direction2D(bisecting: prevOffsetPoint - center, nextOffsetPoint - center)
        let edgeMidpoint = center + bisector.unitVector * offset
        let edgeLine = Line(point: edgeMidpoint, direction: bisector.counterclockwiseNormal)
        let prevLine = Line(point: prevOffsetPoint, direction: prevDir)
        let nextLine = Line(point: nextOffsetPoint, direction: nextDir)
        if let p1 = edgeLine.intersection(with: prevLine),
           let p2 = edgeLine.intersection(with: nextLine) {
            appendIfDistinct(&result, p1, tolerance: tolerance)
            appendIfDistinct(&result, p2, tolerance: tolerance)
        } else {
            appendIfDistinct(&result, prevOffsetPoint, tolerance: tolerance)
            appendIfDistinct(&result, nextOffsetPoint, tolerance: tolerance)
        }

    case .round:
        let arc = arcPointsShortest(
            center: center,
            radius: offset,
            startAngle: atan2(prevOffsetPoint - center),
            endAngle: atan2(nextOffsetPoint - center),
            segmentation: segmentation
        )
        appendPoints(&result, Array(arc.dropFirst()), tolerance: tolerance)
    }
}

internal func arcPointsShortest(
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

internal func appendPoints(_ target: inout [Vector2D], _ points: [Vector2D], tolerance: Double) {
    for point in points {
        appendIfDistinct(&target, point, tolerance: tolerance)
    }
}

internal func appendIfDistinct(_ target: inout [Vector2D], _ point: Vector2D, tolerance: Double) {
    guard let last = target.last else {
        target.append(point)
        return
    }
    if (last - point).magnitude > tolerance {
        target.append(point)
    }
}

internal func deduplicated(points: [Vector2D], tolerance: Double) -> [Vector2D] {
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
