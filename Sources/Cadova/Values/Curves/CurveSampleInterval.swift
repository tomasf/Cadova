import Foundation

/// Specifies the arc-length spacing of samples extracted from a parametric curve.
///
/// Used by `ParametricCurve.readingSamples(at:_:)` and `ParametricCurve.samples(at:segmentation:)`
/// to select a subset of an already-subdivided polyline at requested arc-length positions.
public enum CurveSampleInterval: Sendable, Hashable, Codable {
    /// Sample every `distance` units of arc length along the curve, starting at distance 0.
    ///
    /// - `.includingEndpoints`: pure stride, with a final sample appended at the curve's end
    ///   if the last stride point falls short. The final interval may be shorter than `distance`.
    /// - `.excludingEnd`: pure stride only; matches `stride(from: 0, to: length, by: distance)`.
    ///   Useful for closed loops where the end coincides with the start.
    case step(Double, endpoint: EndpointBehavior = .includingEndpoints)

    /// Emit exactly `count` samples, evenly spaced in arc length.
    ///
    /// - `.includingEndpoints`: spacing = `length / (count - 1)`, with the first sample at the
    ///   curve's start and the last sample at the curve's end.
    /// - `.excludingEnd`: spacing = `length / count`; the first sample is at the start and the
    ///   last sample sits one step before the end. Useful for closed loops.
    ///
    /// `count == 0` yields no samples; `count == 1` yields a single sample at the curve's start.
    case count(Int, endpoint: EndpointBehavior = .includingEndpoints)

    public enum EndpointBehavior: Sendable, Hashable, Codable {
        /// The last sample sits exactly at the curve's end.
        case includingEndpoints

        /// The last sample sits before the curve's end (matching `stride(from:to:by:)` semantics).
        case excludingEnd
    }
}

internal extension CurveSampleInterval {
    /// Returns the target arc-length positions for this interval, given the total curve length.
    /// Distances are returned in ascending order and lie in `0...length`.
    func targetDistances(totalLength length: Double) -> [Double] {
        guard length > 0 else { return [] }

        switch self {
        case .step(let step, let endpoint):
            precondition(step > 0, "CurveSampleInterval.step requires a positive distance")
            var distances: [Double] = []
            var i = 0
            while true {
                let d = Double(i) * step
                if d >= length { break }
                distances.append(d)
                i += 1
            }
            if endpoint == .includingEndpoints, (distances.last ?? -.infinity) < length {
                distances.append(length)
            }
            return distances

        case .count(let count, let endpoint):
            guard count > 0 else { return [] }
            guard count > 1 else { return [0] }
            let step: Double
            switch endpoint {
            case .includingEndpoints: step = length / Double(count - 1)
            case .excludingEnd:       step = length / Double(count)
            }
            return (0..<count).map { Double($0) * step }
        }
    }
}
