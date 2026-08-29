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

    /// A global ceiling on every segment count, read once from `CADOVA_MAX_SEGMENTS`.
    ///
    /// This is deliberately not an environment value. Setting `segmentation` in the
    /// environment is a *default* that any subtree can override with its own
    /// `withSegmentation(...)`, so a model that pins its own resolution cannot be made
    /// coarse from outside. An interactive preview needs exactly that: draw the whole model
    /// roughly, without editing it. Applying the ceiling inside the segment-count funnels
    /// catches every caller, including those overrides.
    ///
    /// Values below 3 are ignored, since 3 is already the floor for a closed shape.
    internal static let maximumCount: Int? = {
        guard let raw = ProcessInfo.processInfo.environment["CADOVA_MAX_SEGMENTS"],
              let value = Int(raw), value >= 3
        else { return nil }
        return value
    }()

    /// The segment counts below are what the geometry is actually built from, so capping
    /// here also changes the node tree — and with it the cache keys. A coarse preview and a
    /// full-resolution build can never be confused for one another.
    private func capped(_ count: Int) -> Int {
        guard let maximum = Self.maximumCount else { return count }
        return Swift.min(count, maximum)
    }

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
            return capped(max(count, 3))

        case .adaptive(let minAngle, let minSize):
            let angularSegmentCount = 360° / minAngle
            let lengthSegmentCount = r * 2 * .pi / minSize
            return capped(Int(max(min(angularSegmentCount, lengthSegmentCount), 5)))
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
            return capped(max(count, 3))

        case .adaptive(_, let minSize):
            return capped(Int(ceil(max(length / minSize, 5))))
        }
    }
}
