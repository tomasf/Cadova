import Foundation

public extension ParametricCurve {
    var labeledControlPoints: [(V, label: String?)]? { nil }

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
        samples(atParameters: _parameterSamples(in: domain, segmentation: segmentation))
    }

    func length(segmentation: Segmentation) -> Double {
        points(segmentation: segmentation)
            .paired()
            .map { ($1 - $0).magnitude }
            .reduce(0, +)
    }

    func points(segmentation: Segmentation) -> [V] {
        points(in: domain, segmentation: segmentation)
    }

    subscript(range: any RangeExpression<Double>) -> Subcurve<Self> {
        Subcurve(base: self, domain: range.resolved(with: domain))
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
        if abs(denom) > 1e-14 {
            initialU = domain.lowerBound + (value - startValue) / denom * span
        } else {
            initialU = (domain.lowerBound + domain.upperBound) / 2
        }

        var u = initialU
        for _ in 0..<maxIterations {
            let p = point(at: u)
            let f = p[axis] - value
            if abs(f) < tolerance {
                return u
            }
            let derivative = _centralDifference(at: u, h: max(1e-6, span * 1e-6), axis: axis)
            if abs(derivative) <= minDerivativeMagnitude {
                break
            }
            u = u - f / derivative
        }
        return nil
    }
}

internal extension ParametricCurve {
    /// Samples at the given parameters, with distances accumulated from the first.
    func samples(atParameters params: [Double]) -> [CurveSample<V>] {
        var samples: [CurveSample<V>] = []
        samples.reserveCapacity(params.count)

        var previousPosition: V? = nil
        var accumulatedDistance = 0.0
        let derivative = derivativeView

        for u in params {
            let position = point(at: u)
            let tangent = derivative.tangent(at: u)
            if let previousPosition {
                accumulatedDistance += (position - previousPosition).magnitude
            }
            samples.append(CurveSample(u: u, position: position, tangent: tangent, distance: accumulatedDistance))
            previousPosition = position
        }
        return samples
    }

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
    /// For `.adaptive`, places samples where the curve turns, following the segmentation's minimum angle and size.
    func _parameterSamples(in interval: ClosedRange<Double>, segmentation: Segmentation) -> [Double] {
        switch segmentation {
        case .fixed(let count):
            let steps = max(0, count)
            let span = interval.upperBound - interval.lowerBound
            if steps == 0 { return [interval.lowerBound] }
            return (0...steps).map { i in
                interval.lowerBound + Double(i) * (span / Double(steps))
            }
        case .adaptive(let minAngle, let minSize):
            return adaptiveParameterSamples(in: interval, minAngle: minAngle, minSize: minSize)
        }
    }
}

/// A curve made of pieces that meet at known parameters, such as the curves of a path, the knots of a spline or the
/// points an interpolating curve passes through. Adaptive sampling always samples these parameters, since the curve
/// can turn sharply there, and probes each piece on its own, so nothing within one goes unseen.
internal protocol ParametricCurveBreakpoints {
    /// The parameters where the curve's pieces meet, in increasing order, or none if the curve doesn't know, such
    /// as a slice of a curve that doesn't.
    var breakpoints: [Double] { get }
}

internal extension ParametricCurve {
    /// Parameters sampling the curve adaptively, following the segmentation's minimum angle and size.
    func adaptiveParameterSamples(in interval: ClosedRange<Double>, minAngle: Angle, minSize: Double) -> [Double] {
        guard let breakpoints = (self as? any ParametricCurveBreakpoints)?.breakpoints, !breakpoints.isEmpty else {
            // A curve that doesn't say where its pieces meet is probed as finely as it would be measured.
            return Segmentation.adaptiveSamples(
                in: interval, minAngle: minAngle, minSize: minSize,
                probeCount: max(4, sampleCountForLengthApproximation)
            ) { point(at: $0) }.map(\.parameter)
        }

        let bounds = [interval.lowerBound]
            + breakpoints.filter { $0 > interval.lowerBound && $0 < interval.upperBound }
            + [interval.upperBound]
        var parameters = [interval.lowerBound]
        for (a, b) in bounds.paired() where b > a {
            parameters += Segmentation.adaptiveSamples(in: a...b, minAngle: minAngle, minSize: minSize) {
                point(at: $0)
            }.dropFirst().map(\.parameter)
        }
        return parameters
    }
}
