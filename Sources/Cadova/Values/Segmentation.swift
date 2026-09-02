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
}
