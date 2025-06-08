import Foundation

internal extension BezierPath {
    func pointsAtPositions(
        in pathFractionRange: ClosedRange<Position>,
        segmentation: EnvironmentValues.Segmentation
    ) -> [(position: Double, point: V)] {
        let (fromCurveIndex, fromFraction) = curveIndexAndFraction(for: pathFractionRange.lowerBound)
        let (toCurveIndex, toFraction) = curveIndexAndFraction(for: pathFractionRange.upperBound)

        return (fromCurveIndex...toCurveIndex).flatMap { index in
            let startFraction = (index == fromCurveIndex) ? fromFraction : 0.0
            let endFraction = (index == toCurveIndex) ? toFraction : 1.0
            let skipFirst = index > fromCurveIndex
            return curves[index].points(in: startFraction..<endFraction, segmentation: segmentation)
                .map { ($0 + Double(index), $1) }
                .dropFirst(skipFirst ? 1 : 0)
        }
    }

    func readPositionsAndPoints<D: Dimensionality>(
        in range: ClosedRange<Position>? = nil,
        reader: @Sendable @escaping ([(Double, V)]) -> D.Geometry
    ) -> D.Geometry {
        readEnvironment { e in
            reader(pointsAtPositions(in: range ?? positionRange, segmentation: e.segmentation))
        }
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

    func position(for target: Double, in axis: V.D.Axis) -> Position? {
        let curveIndex = curveIndex(for: target, in: axis)
        guard let t = curves[curveIndex].t(for: target, in: axis) else {
            return nil
        }
        return Double(curveIndex) + t
    }

    func curveIndexAndFraction(for position: Position) -> (index: Int, fraction: Double) {
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
