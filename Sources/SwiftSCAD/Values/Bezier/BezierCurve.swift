import Foundation

internal struct BezierCurve <V: Vector>: Sendable {
    let controlPoints: [V]

    init(controlPoints: [V]) {
        precondition(controlPoints.count >= 2)
        self.controlPoints = controlPoints
    }

    private func point(at fraction: Double) -> V {
        var workingPoints = controlPoints
        while workingPoints.count > 1 {
            workingPoints = workingPoints.paired().map { $0.point(alongLineTo: $1, at: fraction) }
        }
        return workingPoints[0]
    }

    private func points(in range: Range<Double>, segmentLength: Double) -> [V] {
        let midFraction = (range.lowerBound + range.upperBound) / 2
        let midPoint = point(at: midFraction)
        let distance = point(at: range.lowerBound).distance(to: midPoint) + point(at: range.upperBound).distance(to: midPoint)

        if (distance < segmentLength) || distance < 0.001 {
            return []
        }

        return points(in: range.lowerBound..<midFraction, segmentLength: segmentLength)
        + [midPoint]
        + points(in: midFraction..<range.upperBound, segmentLength: segmentLength)
    }

    private func points(segmentLength: Double) -> [V] {
        return [point(at: 0)] + points(in: 0..<1, segmentLength: segmentLength) + [point(at: 1)]
    }

    private func points(segmentCount: Int) -> [V] {
        let segmentLength = 1.0 / Double(segmentCount)
        return (0...segmentCount).map { f in
            point(at: Double(f) * segmentLength)
        }
    }

    func points(facets: Environment.Facets) -> [V] {
        guard controlPoints.count > 2 else {
            return controlPoints
        }

        switch facets {
        case .fixed (let count):
            return points(segmentCount: count)
        case .dynamic(_, let minSize):
            return points(segmentLength: minSize)
        }
    }

    func transform<T: AffineTransform>(using transform: T) -> Self where T == V.Transform, T.Vector == V {
        Self(controlPoints: controlPoints.map { transform.apply(to: $0) })
    }
}
