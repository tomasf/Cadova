import Foundation

internal extension BezierPath {
    typealias Curve = BezierCurve<V>

    var endPoint: V {
        curves.last?.controlPoints.last ?? startPoint
    }

    var endDirection: Direction<V.D>? {
        curves.last?.tangent(at: 1)
    }

    func adding(curve: Curve) -> BezierPath {
        BezierPath(startPoint: startPoint, curves: curves + [curve])
    }

    func continuousControlPoint(distance: Double) -> V {
        guard let previousCurve = curves.last else {
            preconditionFailure("Adding a continuous segment requires a previous segment to match")
        }
        return endPoint + previousCurve.tangent(at: 1).unitVector * distance
    }

    func subpath(in range: ClosedRange<Double>) -> BezierPath {
        guard !isEmpty else { return self }

        // A collapsed range selects no curve at all. Say so with a curveless path carrying the point the
        // range collapsed onto, rather than fabricating a curve index span (which inverts, and traps) or
        // a single-control-point curve (which sampling then reads out of bounds).
        guard range.length > .ulpOfOne else {
            return BezierPath(startPoint: point(at: range.lowerBound), curves: [])
        }

        let (lowerIndex, lowerFraction) = curveIndexAndFraction(for: range.lowerBound)
        let (upperIndex, upperFraction) = curveIndexAndFraction(for: range.upperBound)

        // A range ending exactly on a curve boundary belongs to the end of the preceding curve, not to a
        // zero-length piece of the next one. The guard above makes this safe: the range spans more than
        // one curve whenever the pull-back applies, so `lastIndex` can never fall below `lowerIndex`.
        var lastIndex = upperIndex
        var lastFraction = upperFraction
        if lastFraction < .ulpOfOne, lastIndex > lowerIndex {
            lastIndex -= 1
            lastFraction = 1.0
        }

        let newCurves: [BezierCurve<V>] = (lowerIndex...lastIndex).map { i in
            let start = (i == lowerIndex) ? lowerFraction : 0
            let end = (i == lastIndex) ? lastFraction : 1
            return (start == 0 && end == 1) ? curves[i] : curves[i].subcurve(in: start...end)
        }
        let newStartPoint = newCurves.first?.controlPoints[0] ?? startPoint
        return BezierPath(startPoint: newStartPoint, curves: newCurves)
    }

    func curveIndexAndFraction(for position: Double) -> (index: Int, fraction: Double) {
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
