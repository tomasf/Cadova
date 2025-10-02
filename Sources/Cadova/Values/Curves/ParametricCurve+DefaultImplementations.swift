import Foundation

public extension ParametricCurve {
    /// Returns rich samples along the curve.
    ///
    /// The first sample’s `distance` is `0`. Each subsequent sample’s `distance`
    /// is the accumulated arc length measured from that first sample (the start
    /// of this extraction).
    ///
    /// - Parameter segmentation: Controls sampling density.
    /// - Returns: An array of `CurveSample`s with accumulated distances.
    ///
    func samples(segmentation: Segmentation) -> [CurveSample<V>] {
        let params = _parameterSamples(in: domain, segmentation: segmentation)
        var samples: [CurveSample<V>] = []
        samples.reserveCapacity(params.count)

        var previousPosition: V? = nil
        var accumulatedDistance = 0.0

        for u in params {
            let sample = sample(at: u)
            if let previousPosition {
                accumulatedDistance += (sample.position - previousPosition).magnitude
            }
            samples.append(CurveSample(u: sample.u, position: sample.position, tangent: sample.tangent, distance: accumulatedDistance))
            previousPosition = sample.position
        }
        return samples
    }

    /// Solves for a parameter `u` whose point has the given coordinate value
    /// along an axis (only valid when the curve is monotone in that axis).
    ///
    /// Uses a Newton solver with central difference derivative approximation.
    /// Performs up to 8 iterations with 1e-6 tolerance and early exit if derivative
    /// magnitude ≤ 1e-10. Initial guess is linear interpolation between domain ends.
    ///
    /// Allows parameters outside `domain` (no clamping).
    ///
    /// - Parameters:
    ///   - value: Target coordinate value.
    ///   - axis: Axis whose coordinate is matched.
    /// - Returns: The parameter `u` if a solution is found, otherwise `nil`.
    func parameter(matching value: Double, along axis: Axis) -> Double? {
        let maxIterations = 8
        let tolerance = 1e-6
        let minDerivativeMagnitude = 1e-10
        let span = domain.length

        // Linear interpolation initial guess between domain ends
        let startValue = point(at: domain.lowerBound)[axis]
        let endValue = point(at: domain.upperBound)[axis]
        let denom = endValue - startValue
        let initialU: Double
        if Swift.abs(denom) > 1e-14 {
            initialU = domain.lowerBound + (value - startValue) / denom * span
        } else {
            initialU = (domain.lowerBound + domain.upperBound) / 2
        }

        var u = initialU
        for _ in 0..<maxIterations {
            let p = point(at: u)
            let f = p[axis] - value
            if Swift.abs(f) < tolerance {
                return u
            }
            let derivative = _centralDifference(at: u, h: max(1e-6, span * 1e-6), axis: axis)
            if Swift.abs(derivative) <= minDerivativeMagnitude {
                break
            }
            u = u - f / derivative
        }
        return nil
    }
}

fileprivate extension ParametricCurve {
    func _centralDifference(at u: Double, h: Double, axis: Axis) -> Double {
        let up = u + h
        let um = u - h
        let fp = point(at: up)[axis]
        let fm = point(at: um)[axis]
        return (fp - fm) / (2 * h)
    }

    /// Returns a sorted array of parameter values for sampling over `interval`.
    ///
    /// For `.fixed(count)`, returns `count+1` uniformly spaced values including both endpoints.
    /// For `.adaptive(_, minSize)`, recursively subdivides based on a chord-length criterion
    /// identical to the Bezier implementation: stop if `(pa→pm + pm→pb) < minSize` or `< 0.001`.
    func _parameterSamples(in interval: ClosedRange<Double>, segmentation: Segmentation) -> [Double] {
        switch segmentation {
        case .fixed(let count):
            let steps = max(0, count)
            let span = interval.upperBound - interval.lowerBound
            if steps == 0 { return [interval.lowerBound] }
            return (0...steps).map { i in
                interval.lowerBound + Double(i) * (span / Double(steps))
            }
        case .adaptive(_, let minSize):
            var params = Set<Double>()
            func subdivide(_ a: Double, _ b: Double) {
                let mid = 0.5 * (a + b)
                let pa = point(at: a)
                let pm = point(at: mid)
                let pb = point(at: b)
                let d = (pa - pm).magnitude + (pm - pb).magnitude
                if d < minSize || d < 0.001 {
                    params.insert(a)
                    params.insert(b)
                } else {
                    subdivide(a, mid)
                    subdivide(mid, b)
                }
            }
            subdivide(interval.lowerBound, interval.upperBound)
            let sorted = params.sorted()
            // Ensure both endpoints are included exactly once
            var result = sorted
            if result.first != interval.lowerBound { result.insert(interval.lowerBound, at: 0) }
            if result.last != interval.upperBound { result.append(interval.upperBound) }
            return result
        }
    }
}
