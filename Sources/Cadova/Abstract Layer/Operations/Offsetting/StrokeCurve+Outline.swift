import Foundation

internal extension StrokeCurve {
    func strokeOffsets() -> (left: Double, right: Double) {
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

    func applySquareCaps(
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

    func buildOutline(
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
}
