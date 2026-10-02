import Foundation

/// Defines how many segments are used to approximate circular and curved geometries.
///
/// Cadova uses segments (sometimes called facets) to approximate curves and circles.
/// The segmentation can be either fixed or adaptive, depending on your precision and performance needs.
/// 
public enum Segmentation: Sendable, Hashable, Codable {
    /// Uses a fixed number of segments for all circular or curved geometries, regardless of size.
    ///
    /// - Parameter count: The number of segments to use (minimum 3).
    case fixed (Int)

    /// Uses an adaptive segmentation strategy based on angular and linear thresholds.
    ///
    /// This option dynamically adjusts the number of segments depending on the size and curvature
    /// of the geometry. It aims to balance detail and performance.
    ///
    /// `minSize` is a length, and is measured in the coordinate system where the segmentation is set. Scaling
    /// geometry after the fact scales the segmentation with it, leaving the shape of the result unchanged.
    ///
    /// - Parameters:
    ///   - minAngle: The minimum angle per segment.
    ///   - minSize: The minimum segment length.
    case adaptive (minAngle: Angle, minSize: Double)

    /// The default segmentation strategy used in Cadova.
    ///
    /// This value is an adaptive strategy with a reasonable balance
    /// between performance and visual quality.
    public static let defaults = Segmentation.adaptive(minAngle: 2°, minSize: 0.15)

    /// Computes the number of segments required to approximate a full circle of the given radius.
    ///
    /// The number of segments is determined either by a fixed count or, in adaptive mode, based on
    /// a minimum angle between segments and a minimum linear segment length.
    ///
    /// - Parameter r: The radius of the circle.
    /// - Returns: The computed segment count. Fixed segmentation uses at least 3 segments;
    ///   adaptive segmentation uses at least 5.
    ///
    public func segmentCount(circleRadius r: Double) -> Int {
        switch self {
        case .fixed (let count):
            return max(count, 3)

        case .adaptive(let minAngle, let minSize):
            let angularSegmentCount = 360° / minAngle
            let lengthSegmentCount = r * 2 * .pi / minSize
            return Int(max(min(angularSegmentCount, lengthSegmentCount), 5))
        }
    }

    /// Computes the number of segments required to approximate an arc with a given radius and angle.
    ///
    /// This method estimates how many linear segments are needed to accurately approximate a curved arc
    /// based on the provided radius and angle.
    ///
    /// - Parameters:
    ///   - r: The radius of the arc.
    ///   - angle: The total angle of the arc.
    /// - Returns: The computed segment count, with a minimum of 2 segments.
    ///
    public func segmentCount(arcRadius r: Double, angle: Angle) -> Int {
        return max(Int(ceil(Double(segmentCount(circleRadius: r)) * angle / 360°)), 2)
    }

    /// Computes the number of segments required to approximate a curve of the given length.
    ///
    /// In adaptive mode, the number of segments is calculated based on the minimum allowed
    /// segment length and uses at least 5 segments. Fixed segmentation uses at least 3.
    ///
    /// - Parameter length: The total length of the curve.
    /// - Returns: The computed segment count.
    ///
    public func segmentCount(length: Double) -> Int {
        switch self {
        case .fixed (let count):
            return max(count, 3)

        case .adaptive(_, let minSize):
            return Int(ceil(max(length / minSize, 5)))
        }
    }
}

internal extension Segmentation {
    /// How many pieces a stretch of curve needs, judged from points sampled evenly across it by parameter.
    ///
    /// Adaptive segmentation splits a stretch only while it's both longer than `minSize` and turns by more than
    /// `minAngle`, the same rule `segmentCount(circleRadius:)` follows for circles, so a straight stretch is never
    /// split however long it is.
    static func adaptivePieceCount<V: Vector>(across samples: [V], minAngle: Angle, minSize: Double) -> Int {
        let (length, turn) = lengthAndTurn(across: samples)
        return adaptivePieceCount(length: length, turn: turn, minAngle: minAngle, minSize: minSize)
    }

    /// How many pieces a stretch of the given length, turning through the given angle in radians, needs.
    static func adaptivePieceCount(length: Double, turn: Double, minAngle: Angle, minSize: Double) -> Int {
        guard length > 1e-9 else { return 1 }
        let byLength = minSize > 0 ? (length / minSize).rounded(.up) : .infinity
        let byAngle = minAngle.radians > 0 ? (turn / minAngle.radians).rounded(.up) : (turn > 1e-9 ? .infinity : 1)
        let pieces = min(byLength, byAngle)
        guard pieces.isFinite else { return maximumPiecesPerStep }
        return Int(pieces.clamped(to: 1...Double(maximumPiecesPerStep)))
    }

    /// The length of a polyline through the samples, and the angle in radians it turns through, scaled up to the
    /// arc it stands in for: a polyline of `n` chords across an arc only turns at its `n − 1` inner points, through
    /// `(n − 1) / n` of the arc's angle.
    static func lengthAndTurn<V: Vector>(across samples: [V]) -> (length: Double, turn: Double) {
        var length = 0.0
        var turn = 0.0
        var previousChord: V? = nil
        for index in samples.indices.dropLast() {
            let chord = samples[index + 1] - samples[index]
            let chordLength = chord.magnitude
            length += chordLength
            // A chord of no length, at a cusp or where a surface collapses to a point, has no direction to turn from.
            guard chordLength > 1e-12 else { continue }
            if let previousChord {
                turn += Self.angle(between: previousChord, and: chord)
            }
            previousChord = chord
        }
        let chordCount = Double(samples.count - 1)
        return (length, chordCount > 1 ? turn * chordCount / (chordCount - 1) : 0)
    }

    /// The angle between two vectors, in radians.
    static func angle<V: Vector>(between a: V, and b: V) -> Double {
        Foundation.acos(((a ⋅ b) / (a.magnitude * b.magnitude)).clamped(to: -1...1))
    }

    /// Splits a stretch into at most this many pieces at a time, before looking at each piece again.
    static var maximumPiecesPerStep: Int { 64 }

    /// Samples a curve adaptively: as few points as the rule in `adaptivePieceCount(across:minAngle:minSize:)` allows,
    /// placed where the curve turns.
    ///
    /// - Parameters:
    ///   - range: The parameter range to sample.
    ///   - probeCount: How many chords to probe the whole range with before deciding how to split it. A curve made of
    ///     several spans, such as a spline, should probe each of them, or a feature between two probes goes unseen.
    ///     Probing doesn't add points to the result.
    ///   - point: The curve's point at a parameter.
    /// - Returns: The parameters and points, starting at the range's start and ending at its end.
    static func adaptiveSamples<V: Vector>(
        in range: ClosedRange<Double>,
        minAngle: Angle,
        minSize: Double,
        probeCount: Int = 4,
        point: (Double) -> V
    ) -> [(parameter: Double, point: V)] {
        let start = point(range.lowerBound)
        var samples: [(parameter: Double, point: V)] = [(range.lowerBound, start)]

        func sample(from a: Double, _ pa: V, to b: Double, _ pb: V, probeCount: Int, depth: Int) {
            let probes = [pa] + (1..<probeCount).map { point(a + (b - a) * Double($0) / Double(probeCount)) } + [pb]
            // Past this depth the parameter range has been split far finer than anything worth drawing, which only
            // happens at a cusp with no minimum size to stop at.
            let pieces = depth < 24 ? adaptivePieceCount(across: probes, minAngle: minAngle, minSize: minSize) : 1
            guard pieces > 1 else {
                samples.append((b, pb))
                return
            }

            var previous = (a, pa)
            for index in 1...pieces {
                let t = index == pieces ? b : a + (b - a) * Double(index) / Double(pieces)
                let pt = index == pieces ? pb : point(t)
                sample(from: previous.0, previous.1, to: t, pt, probeCount: max(4, probeCount / pieces), depth: depth + 1)
                previous = (t, pt)
            }
        }

        sample(from: range.lowerBound, start, to: range.upperBound, point(range.upperBound), probeCount: max(probeCount, 2), depth: 0)
        return samples
    }

    /// The surface deviation this segmentation already accepts everywhere else, used as the budget
    /// for deciding whether a loft needs another ring.
    ///
    /// Adaptive segmentation states two limits on a *chord*: `minSize` is the shortest chord worth
    /// emitting, and `minAngle` the smallest turn worth resolving. Both bind at once on a circle of
    /// radius `r = minSize / (2·sin(minAngle/2))`, and the sagitta there — the gap between the chord
    /// and the arc it stands in for — is
    ///
    ///     s = r · (1 − cos(minAngle / 2)) = minSize · tan(minAngle / 4) / 2
    ///
    /// The radius cancels out, leaving the one error budget the two limits agree on. Spending that
    /// same budget along the path makes a ring inserted between two sections worth exactly what a
    /// vertex inserted around a ring is worth, so a loft's surface ends up neither coarser nor finer
    /// than the circles it interpolates. With the defaults (2°, 0.15 mm) it comes to 0.65 µm.
    ///
    /// `\.tolerance` deliberately plays no part in this. That value is a fit clearance between mating
    /// parts, orders of magnitude larger than a tessellation error; spending it here would let the
    /// surface wander by the whole gap it exists to guarantee.
    static func surfaceDeviation(minAngle: Angle, minSize: Double) -> Double {
        minSize * tan(minAngle / 4) / 2
    }

    /// How many points to probe when looking for the place a loft's surface departs furthest from a
    /// straight band, over a stretch of path `pathLength` long that the path itself sampled at
    /// `pathSampleCount` points.
    ///
    /// This is a detection resolution, not an output resolution, so it is deliberately finer than
    /// anything that gets built. The count comes from the two things that already bound how fine the
    /// output can be. `segmentCount(length:)` is the most bands this segmentation would ever emit
    /// over that length, and the path's own sample count is how finely the path was resolved, which
    /// on a tight curve is the denser of the two. A feature narrower than the shorter of those two
    /// spacings cannot be drawn, so probing finer than that can never change the mesh.
    ///
    /// The factor of four is headroom. Two samples per feature is the bare minimum to see a feature
    /// at all, and four keeps detection comfortably away from being the limit, so the thing that
    /// bounds accuracy stays the segmentation rather than the search.
    ///
    /// Probing is scalar arithmetic and costs nothing next to building a ring, so the only reason to
    /// bound the count at all is to keep a very long path from paying for samples it cannot use. At
    /// the cap the probe still matches `minSize` exactly on a path of about two and a half metres,
    /// and only drops below four times oversampling beyond that.
    func deviationProbeCount(pathLength: Double, pathSampleCount: Int) -> Int {
        let byLength = segmentCount(length: pathLength)
        return min(4 * max(byLength, pathSampleCount), 65536)
    }
}
