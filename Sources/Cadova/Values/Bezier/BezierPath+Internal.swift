import Foundation

internal extension BezierPath {
    func pointsAtPositions(segmentation: Segmentation) -> [(fraction: Fraction, point: V)] {
        curves.indices.flatMap { index in
            curves[index].points(segmentation: segmentation)
                .map { ($0 + Double(index), $1) }
                .dropFirst(index > 0 ? 1 : 0)
        }
    }

    func simplePolygon(in environment: EnvironmentValues) -> SimplePolygon where V == Vector2D {
        SimplePolygon(points(segmentation: environment.segmentation))
    }
}

// For paths that are monotonic over axis
internal extension BezierPath {
    func range(for axis: V.D.Axis) -> Range<Double> {
        guard let lastCurve = curves.last else { return 0..<0 }
        let lastPoint = lastCurve.controlPoints.last!
        return startPoint[axis]..<lastPoint[axis]
    }

    func curveIndex(for value: Double, in axis: V.D.Axis) -> Int {
        curves.firstIndex(where: {
            value <= $0.controlPoints.last![axis]
        }) ?? curves.count - 1
    }

    func position(for target: Double, in axis: V.D.Axis) -> Fraction? {
        let curveIndex = curveIndex(for: target, in: axis)
        guard let t = curves[curveIndex].t(for: target, in: axis) else {
            return nil
        }
        return Double(curveIndex) + t
    }

    func curveIndexAndFraction(for position: Fraction) -> (index: Int, fraction: Double) {
        if position < 0 {
            return (0, position)
        } else if position >= Double(curves.count) {
            return (curves.count - 1, position - Double(curves.count - 1))
        } else {
            let index = floor(position)
            return (Int(index), position - index)
        }
    }
}
