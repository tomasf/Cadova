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
        let (lowerIndex, lowerFraction) = curveIndexAndFraction(for: range.lowerBound)
        var (upperIndex, upperFraction) = curveIndexAndFraction(for: range.upperBound)

        if upperIndex > 0, upperFraction < Double.ulpOfOne {
            upperIndex -= 1
            upperFraction = 1.0
        }

        let newCurves: [BezierCurve<V>] = (lowerIndex...upperIndex).map { i in
            let start = (i == lowerIndex) ? lowerFraction : 0
            let end = (i == upperIndex) ? upperFraction : 1
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
