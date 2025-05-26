import Foundation

internal struct BezierCurve<V: Vector>: Sendable, Hashable, Codable {
    let controlPoints: [V]

    init(controlPoints: [V]) {
        self.controlPoints = controlPoints
    }

    internal func point(at fraction: Double) -> V {
        var workingPoints = controlPoints
        while workingPoints.count > 1 {
            workingPoints = workingPoints.paired().map { $0.point(alongLineTo: $1, at: fraction) }
        }
        return workingPoints[0]
    }

    // Returns the Bezier curve that represents the derivative of this curve.
    internal var derivative: BezierCurve<V> {
        let n = controlPoints.count - 1
        return BezierCurve(controlPoints: (0..<n).map { i in
            (controlPoints[i + 1] - controlPoints[i]) * Double(n)
        })
    }

    func tangent(at fraction: Double) -> Direction<V.D> {
        Direction(derivative.point(at: fraction))
    }

    private func points(in range: Range<Double>, segmentLength: Double) -> [(Double, V)] {
        let midFraction = (range.lowerBound + range.upperBound) / 2
        let midPoint = point(at: midFraction)
        let distance = point(at: range.lowerBound).distance(to: midPoint) + point(at: range.upperBound).distance(to: midPoint)

        if (distance < segmentLength) || distance < 0.001 {
            return []
        }

        return points(in: range.lowerBound..<midFraction, segmentLength: segmentLength)
        + [(midFraction, midPoint)]
        + points(in: midFraction..<range.upperBound, segmentLength: segmentLength)
    }

    private func points(in range: Range<Double>, segmentCount: Int) -> [(Double, V)] {
        let segmentInterval = (range.upperBound - range.lowerBound) / Double(segmentCount)
        return (0...segmentCount).map { f in
            let t = range.lowerBound + Double(f) * segmentInterval
            return (t, point(at: t))
        }
    }

    func points(in range: Range<Double>, segmentation: EnvironmentValues.Segmentation) -> [(Double, V)] {
        switch segmentation {
        case .fixed (let count):
            return points(in: range, segmentCount: count)
        case .adaptive(_, let minSize):
            return points(in: range, segmentLength: minSize)
        }
    }

    private func points(segmentLength: Double) -> [(Double, V)] {
        return [(0, point(at: 0))] + points(in: 0..<1, segmentLength: segmentLength) + [(1, point(at: 1))]
    }

    private func points(segmentCount: Int) -> [(Double, V)] {
        let segmentInterval = 1.0 / Double(segmentCount)
        return (0...segmentCount).map { f in
            let t = Double(f) * segmentInterval
            return (t, point(at: t))
        }
    }

    func points(segmentation: EnvironmentValues.Segmentation) -> [(Double, V)] {
        switch segmentation {
        case .fixed (let count):
            return points(segmentCount: count)
        case .adaptive(_, let minSize):
            return points(segmentLength: minSize)
        }
    }

    func transformed<T: Transform>(using transform: T) -> Self where T == V.D.Transform, T.V == V {
        Self(controlPoints: controlPoints.map { transform.apply(to: $0) })
    }

    var endDirection: V {
        let last = controlPoints[controlPoints.count - 1]
        let secondLast = controlPoints[controlPoints.count - 2]
        return (last - secondLast).normalized
    }

    func map<V2: Vector>(_ transform: (V) -> V2) -> BezierCurve<V2> {
        .init(controlPoints: controlPoints.map(transform))
    }

    func approximateLength(segmentCount: Int) -> Double {
        points(segmentCount: segmentCount).paired().map { ($1.0 - $0.0).magnitude }.reduce(0, +)
    }
}

extension BezierCurve {
    /// Solves for `t` such that the `axis` component of the point at `t` is approximately `target`.
    ///
    /// - Important: Only works for monotonic curves in the axis direction.
    /// - Parameters:
    ///   - target: The target value to solve for.
    ///   - axis: The axis for the target value.
    /// - Returns: The value of `t` (not clamped to [0, 1]) such that point(at: t)[axis] ≈ target, or `nil` if not found.
    ///   Values outside [0, 1] are allowed if the curve extends in that direction.
    func t(for target: Double, in axis: V.D.Axis) -> Double? {
        let maxIterations = 8
        let tolerance = 1e-6
        let derived = derivative
        let a = controlPoints.first![axis]
        let b = controlPoints.last![axis]
        var t = ((target - a) / (b - a))
        guard !t.isNaN else { return nil }

        for _ in 0..<maxIterations {
            let value = point(at: t)[axis]
            let delta = derived.point(at: t)[axis]

            let error = value - target
            if Swift.abs(error) < tolerance {
                return t
            }

            guard Swift.abs(delta) > 1e-10 else {
                break // Avoid division by zero
            }
            t -= error / delta
        }

        return nil
    }

}

extension BezierCurve: CustomDebugStringConvertible {
    public var debugDescription: String {
        controlPoints.map { $0.debugDescription }.joined(separator: ",  ")
    }
}
