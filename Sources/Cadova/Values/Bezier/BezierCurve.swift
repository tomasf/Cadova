import Foundation

internal struct BezierCurve<V: Vector>: Sendable, Hashable, Codable {
    let controlPoints: [V]

    init(controlPoints: [V]) {
        self.controlPoints = controlPoints
    }

    func point(at fraction: Double) -> V {
        var workingPoints = controlPoints
        while workingPoints.count > 1 {
            workingPoints = workingPoints.paired().map { $0.point(alongLineTo: $1, at: fraction) }
        }
        return workingPoints[0]
    }

    // Returns the Bezier curve that represents the derivative of this curve.
    var derivative: BezierCurve<V> {
        let n = controlPoints.count - 1
        return BezierCurve(controlPoints: (0..<n).map { i in
            (controlPoints[i + 1] - controlPoints[i]) * Double(n)
        })
    }

    func tangent(at fraction: Double) -> Direction<V.D> {
        Direction(derivative.point(at: fraction))
    }

    private func points(in range: Range<Double>, segmentLength: Double) -> [(Double, V)] {
        let midFraction = range.mid
        let midPoint = point(at: midFraction)
        let distance1 = point(at: range.lowerBound).distance(to: midPoint)
        let distance2 = point(at: range.upperBound).distance(to: midPoint)
        let distance = distance1 + distance2

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

    func points(in range: Range<Double> = 0..<1, segmentation: EnvironmentValues.Segmentation) -> [(Double, V)] {
        switch segmentation {
        case .fixed (let count):
            points(in: range, segmentCount: count)
        case .adaptive(_, let minSize):
            [(range.lowerBound, point(at: range.lowerBound))]
            + points(in: range, segmentLength: minSize)
            + [(range.upperBound, point(at: range.upperBound))]
        }
    }

    func transformed<T: Transform>(using transform: T) -> Self where T == V.D.Transform, T.V == V {
        Self(controlPoints: controlPoints.map { transform.apply(to: $0) })
    }

    func map<V2: Vector>(_ transform: (V) -> V2) -> BezierCurve<V2> {
        .init(controlPoints: controlPoints.map(transform))
    }

    func approximateLength(segmentCount: Int) -> Double {
        points(segmentation: .fixed(segmentCount)).paired().map { ($1.0 - $0.0).magnitude }.reduce(0, +)
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

extension BezierCurve {
    /// Returns a sub-curve spanning `tRange` using two De Casteljau splits.
    ///
    /// Algorithm
    /// 1. Split the curve at t₁ = `tRange.upperBound`, keeping the left piece.
    /// 2. Split that piece at t₀′ = `tRange.lowerBound / t₁`, keeping the right piece.
    ///
    /// This is the classic, numerically robust way to extract a Bézier segment.
    func trimmed(to tRange: ClosedRange<Double>) -> BezierCurve<V> {
        let t0 = tRange.lowerBound
        let t1 = tRange.upperBound

        // De Casteljau split helper
        func split(_ pts: [V], at t: Double) -> ([V], [V]) {
            var left:  [V] = [pts.first!]
            var right: [V] = [pts.last!]
            var layer = pts
            while layer.count > 1 {
                layer = zip(layer, layer.dropFirst()).map { $0 + ($1 - $0) * t }
                left.append(layer.first!)
                right.append(layer.last!)
            }
            return (left, right.reversed())
        }

        // 1. Cut at t₁
        let (leftPiece, _) = split(controlPoints, at: t1)

        // 2. Cut that piece at rescaled t₀′
        let (_, trimmed) = split(leftPiece, at: t0 / t1)

        return BezierCurve(controlPoints: trimmed)
    }
}
