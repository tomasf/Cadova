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
        StrokeCurve(
            curve: self,
            width: width,
            alignment: alignment,
            style: style
        )
    }

    /// Converts the curve into a stroked 2D geometry, providing both the curve and its stroke to a builder closure.
    ///
    /// This method creates a stroked version of the curve and passes both the original curve
    /// and the stroke geometry to the supplied builder closure. This enables composition
    /// with other geometry derived from the same curve.
    ///
    /// - Parameters:
    ///   - width: The thickness of the stroke. Must be positive.
    ///   - alignment: How the stroke is positioned relative to the curve direction.
    ///   - style: The line join style for corners (e.g., `.round`, `.miter`, `.bevel`).
    ///   - reader: A closure that receives both the original curve and the stroked geometry, and returns a new composed geometry.
    /// - Returns: The result of the builder closure.
    ///
    /// - SeeAlso: ``stroked(width:alignment:style:)``
    ///
    func stroked<Output: Dimensionality>(
        width: Double,
        alignment: CurveStrokeAlignment = .centered,
        style: LineJoinStyle = .miter,
        @GeometryBuilder<Output> reader: @escaping @Sendable (_ curve: Self, _ stroked: any Geometry2D) -> Output.Geometry
    ) -> Output.Geometry {
        reader(self, stroked(width: width, alignment: alignment, style: style))
    }
}

private struct StrokeCurve<Curve: ParametricCurve<Vector2D>>: Shape2D {
    let curve: Curve
    let width: Double
    let alignment: CurveStrokeAlignment
    let style: LineJoinStyle

    var body: any Geometry2D {
        @Environment(\.scaledSegmentation) var segmentation
        @Environment(\.miterLimit) var miterLimit
        @Environment(\.lineCapStyle) var capStyle

        CachedNode(
            name: "strokeCurve",
            parameters: curve, width, alignment, style, capStyle, segmentation, miterLimit
        ) {
            guard width > 0 else { return Empty() }
            let sampledPoints = curve.points(segmentation: segmentation)
            let outline = strokeOutline(
                points: sampledPoints,
                capStyle: capStyle,
                segmentation: segmentation,
                miterLimit: miterLimit
            )
            guard outline.isEmpty == false else { return Empty() }
            return Polygon(outline)
        }
    }
    
    private func strokeOutline(
        points: [Vector2D],
        capStyle: LineCapStyle,
        segmentation: Segmentation,
        miterLimit: Double
    ) -> [Vector2D] {
        let epsilon = 1e-9
        let filteredPoints = deduplicated(points: points, tolerance: epsilon)
        guard filteredPoints.count >= 2 else { return [] }

        let offsets = strokeOffsets()
        let leftOffset = offsets.left
        let rightOffset = offsets.right
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
            applySquareCaps(
                leftPoints: &leftPoints,
                rightPoints: &rightPoints,
                filteredPoints: filteredPoints,
                leftOffset: leftOffset,
                rightOffset: rightOffset
            )
        }

        return buildOutline(
            leftPoints: leftPoints,
            rightPoints: rightPoints,
            filteredPoints: filteredPoints,
            capStyle: capStyle,
            segmentation: segmentation,
            leftOffset: leftOffset,
            rightOffset: rightOffset,
            epsilon: epsilon
        )
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

        let (directions, normals) = polylineVectors(points: points, isLeft: isLeft)
        let segmentCount = directions.count

        var result: [Vector2D] = []
        appendIfDistinct(&result, points[0] + normals[0].unitVector * offset, tolerance: epsilon)

        for i in 1..<(points.count - 1) {
            let prevDir = directions[i - 1]
            let nextDir = directions[i]
            let cross = prevDir.unitVector × nextDir.unitVector
            let prevNormal = normals[i - 1]
            let nextNormal = normals[i]
            let prevOffsetPoint = points[i] + prevNormal.unitVector * offset
            let nextOffsetPoint = points[i] + nextNormal.unitVector * offset

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
                center: points[i],
                offset: offset,
                style: style,
                segmentation: segmentation,
                miterLimit: miterLimit,
                tolerance: epsilon
            )
        }

        appendIfDistinct(&result, points[points.count - 1] + normals[segmentCount - 1].unitVector * offset, tolerance: epsilon)
        return result
    }

    private func strokeOffsets() -> (left: Double, right: Double) {
        let halfWidth = width / 2.0
        switch alignment {
        case .centered:
            return (halfWidth, halfWidth)
        case .left:
            return (width, 0)
        case .right:
            return (0, width)
        }
    }

    private func applySquareCaps(
        leftPoints: inout [Vector2D],
        rightPoints: inout [Vector2D],
        filteredPoints: [Vector2D],
        leftOffset: Double,
        rightOffset: Double
    ) {
        let capExtension = max(leftOffset, rightOffset)
        guard capExtension > 0 else { return }
        let startDir = (filteredPoints[1] - filteredPoints[0]).normalized
        let endDir = (filteredPoints[filteredPoints.count - 1] - filteredPoints[filteredPoints.count - 2]).normalized
        let startShift = startDir * capExtension
        let endShift = endDir * capExtension
        leftPoints[0] -= startShift
        rightPoints[0] -= startShift
        leftPoints[leftPoints.count - 1] += endShift
        rightPoints[rightPoints.count - 1] += endShift
    }

    private func buildOutline(
        leftPoints: [Vector2D],
        rightPoints: [Vector2D],
        filteredPoints: [Vector2D],
        capStyle: LineCapStyle,
        segmentation: Segmentation,
        leftOffset: Double,
        rightOffset: Double,
        epsilon: Double
    ) -> [Vector2D] {
        var outline: [Vector2D] = []
        appendPoints(&outline, leftPoints, tolerance: epsilon)

        let leftEnd = leftPoints[leftPoints.count - 1]
        let rightEnd = rightPoints[rightPoints.count - 1]
        let leftStart = leftPoints[0]
        let rightStart = rightPoints[0]

        let capRadius = (leftOffset + rightOffset) / 2
        let useRoundCaps = capStyle == .round && capRadius > 0
        if useRoundCaps {
            let endDirection = Direction2D(filteredPoints[filteredPoints.count - 1] - filteredPoints[filteredPoints.count - 2])
            let endNormal = endDirection.counterclockwiseNormal.unitVector
            let endCenter = filteredPoints[filteredPoints.count - 1] + endNormal * (leftOffset - rightOffset) / 2
            appendRoundCap(
                outline: &outline,
                center: endCenter,
                radius: capRadius,
                startPoint: leftEnd,
                endPoint: rightEnd,
                segmentation: segmentation,
                epsilon: epsilon
            )
        } else {
            appendIfDistinct(&outline, rightEnd, tolerance: epsilon)
        }

        appendPoints(&outline, Array(rightPoints.reversed().dropFirst()), tolerance: epsilon)

        if useRoundCaps {
            let startDirection = Direction2D(filteredPoints[1] - filteredPoints[0])
            let startNormal = startDirection.counterclockwiseNormal.unitVector
            let startCenter = filteredPoints[0] + startNormal * (leftOffset - rightOffset) / 2
            appendRoundCap(
                outline: &outline,
                center: startCenter,
                radius: capRadius,
                startPoint: rightStart,
                endPoint: leftStart,
                segmentation: segmentation,
                epsilon: epsilon
            )
        } else {
            appendIfDistinct(&outline, leftStart, tolerance: epsilon)
        }

        return outline
    }

    private func appendRoundCap(
        outline: inout [Vector2D],
        center: Vector2D,
        radius: Double,
        startPoint: Vector2D,
        endPoint: Vector2D,
        segmentation: Segmentation,
        epsilon: Double
    ) {
        let arc = arcPoints(
            center: center,
            radius: radius,
            startAngle: atan2(startPoint - center),
            endAngle: atan2(endPoint - center),
            clockwise: true,
            segmentation: segmentation
        )
        appendPoints(&outline, Array(arc.dropFirst()), tolerance: epsilon)
    }

    private func polylineVectors(
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
            // Position the flat edge so its midpoint is exactly offset distance from center
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
                // Fall back to bevel if intersection fails
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
}
