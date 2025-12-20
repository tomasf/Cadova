import Foundation

internal struct BezierCurve<V: Vector>: Sendable, Hashable, Codable {
    let controlPoints: [V]

    init(controlPoints: [V]) {
        precondition(controlPoints.isEmpty == false)
        self.controlPoints = controlPoints
    }

    func point(at fraction: Double) -> V {
        var workingPoints = controlPoints
        while workingPoints.count > 1 {
            workingPoints = workingPoints.paired().map { $0 + ($1 - $0) * fraction }
        }
        return workingPoints[0]
    }

    var degree: Int {
        controlPoints.count - 1
    }

    // A Bezier curve that represents the derivative of this curve.
    var derivative: BezierCurve<V> {
        BezierCurve(controlPoints: controlPoints.paired().map { ($1 - $0) * Double(degree) })
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

    func points(in range: Range<Double> = 0..<1, segmentation: Segmentation, subdividingStraightLines: Bool) -> [(Double, V)] {
        guard subdividingStraightLines || controlPoints.count > 2 else {
            let p1 = controlPoints[0] + (controlPoints[1] - controlPoints[0]) * range.lowerBound
            let p2 = controlPoints[0] + (controlPoints[1] - controlPoints[0]) * range.upperBound
            return [(range.lowerBound, p1), (range.upperBound, p2)]
        }

        return switch segmentation {
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
        points(segmentation: .fixed(segmentCount), subdividingStraightLines: false)
            .paired().map { ($1.0 - $0.0).magnitude }.reduce(0, +)
    }

    func reversed() -> Self {
        Self(controlPoints: controlPoints.reversed())
    }
}

extension BezierCurve {
    /// Solves for `t` such that the `axis` component of the point at `t` is approximately `target`.
    ///
    /// - Important: Only works for monotonic curves in the axis direction.
    /// - Parameters:
    ///   - target: The target value to solve for.
    ///   - axis: The axis for the target value.
    /// - Returns: The value of `t` (not clamped to [0, 1]) such that point(at: t)[axis] ≈ target, or `nil`
    ///   if not found.
    ///   Values outside [0, 1] are allowed if the curve extends in that direction.
    ///   
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
            if abs(error) < tolerance {
                return t
            }

            guard abs(delta) > 1e-10 else {
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
    // Returns a sub-curve spanning `range` using two De Casteljau splits.
    func subcurve(in range: ClosedRange<Double>) -> BezierCurve<V> {
        guard abs(range.length) > .ulpOfOne else {
            return BezierCurve(controlPoints: [point(at: range.lowerBound)])
        }

        // De Casteljau split helper
        func split(_ pts: [V], at t: Double) -> ([V], [V]) {
            var layer = pts, left = [V](), right = [V]()
            while layer.count > 0 {
                left.append(layer.first!)
                right.insert(layer.last!, at: 0)
                layer = layer.paired().map { $0 + ($1 - $0) * t }
            }
            return (left, right)
        }

        if abs(range.upperBound) > .ulpOfOne {
            let (left, _) = split(controlPoints, at: range.upperBound)
            let (_, segment) = split(left, at: range.lowerBound / range.upperBound)
            return BezierCurve(controlPoints: segment)
        } else {
            let (_, right) = split(controlPoints, at: range.lowerBound)
            let (_, segment) = split(right, at: range.length / (1 - range.lowerBound))
            return BezierCurve(controlPoints: segment)
        }
    }
}
