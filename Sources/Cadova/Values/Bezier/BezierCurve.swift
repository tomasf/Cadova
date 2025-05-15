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
}

extension BezierCurve<Vector2D> {
    /// Solves for `t` such that the x component of the point at `t` is approximately `xTarget`.
    ///
    /// - Important: Only works for monotonic curves in the x direction.
    /// - Parameters:
    ///   - xTarget: The target x value to solve for.
    /// - Returns: The value of `t` in [0, 1] such that point(at: t).x ≈ xTarget, or `nil` if not found.
    func t(forX xTarget: Double) -> Double? {
        let maxIterations = 8
        let tolerance = 1e-6
        var t = xTarget

        // Clamp t to range
        t = t.clamped(to: 0...1)

        for _ in 0..<maxIterations {
            let x = point(at: t).x
            let dx = derivative.point(at: t).x

            let error = x - xTarget
            if Swift.abs(error) < tolerance {
                return t
            }

            if Swift.abs(dx) < 1e-10 {
                break // Avoid division by zero
            }

            let tNext = t - error / dx
            if tNext < 0 || tNext > 1 {
                break // Out of bounds
            }

            t = tNext
        }

        return nil
    }
}

extension BezierCurve: CustomDebugStringConvertible {
    public var debugDescription: String {
        controlPoints.map { $0.debugDescription }.joined(separator: ",  ")
    }
}
