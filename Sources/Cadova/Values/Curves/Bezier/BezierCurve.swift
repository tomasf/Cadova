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

    /// The largest distance from the first control point to any other. Used as the curve's own length
    /// scale, so tolerances below are relative rather than assuming millimetre-sized geometry.
    private var controlPolygonExtent: Double {
        controlPoints.dropFirst().reduce(0) { Swift.max($0, controlPoints[0].distance(to: $1)) }
    }

    /// The direction of travel at `fraction`.
    ///
    /// Ordinarily this is just the first derivative, but a curve whose control points coincide at that
    /// end has a first derivative of exactly zero there — a cubic leaving its start point with no
    /// tension is a perfectly ordinary way to author a curve — and `Direction` would normalize that zero
    /// vector into a zero-length "unit" direction without complaint, producing a frame with no Z axis or
    /// a plane with no normal further downstream.
    ///
    /// L'Hôpital's rule gives the true tangent as the first derivative that doesn't vanish, so fall back
    /// to the second, and finally to the chord across the whole curve.
    func tangent(at fraction: Double) -> Direction<V.D> {
        guard controlPoints.count > 1 else { return .undefined }
        let epsilon = controlPolygonExtent * 1e-9

        let firstDerivative = derivative
        let velocity = firstDerivative.point(at: fraction)
        if velocity.magnitude > epsilon { return Direction(velocity) }

        if firstDerivative.controlPoints.count > 1 {
            // B'(t₀ + h) ≈ B''(t₀)·h, so B'' gives the direction of travel for h > 0. At the very end of
            // the curve the only h available points backwards, and the sign flips with it.
            let sign: Double = fraction >= 1 ? -1 : 1
            let acceleration = firstDerivative.derivative.point(at: fraction) * sign
            if acceleration.magnitude > epsilon { return Direction(acceleration) }
        }

        let chord = controlPoints.last! - controlPoints.first!
        return chord.magnitude > epsilon ? Direction(chord) : .undefined
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
        // A curve collapsed onto a single control point (from `subcurve(in:)` over a degenerate range)
        // is that point everywhere; it has no interior to sample and no second control point to read.
        if controlPoints.count == 1 {
            return [(range.lowerBound, controlPoints[0]), (range.upperBound, controlPoints[0])]
        }

        if !subdividingStraightLines, controlPoints.count == 2 {
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
