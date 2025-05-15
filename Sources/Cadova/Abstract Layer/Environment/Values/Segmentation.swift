import Foundation

public extension EnvironmentValues {
    static private let environmentKey = Key("Cadova.Segmentation")

    /// Defines how many segments are used to approximate circular and curved geometries.
    ///
    /// Cadova uses segments (sometimes called facets) to approximate curves and circles.
    /// The segmentation can be either fixed or adaptive, depending on your precision and performance needs.

    enum Segmentation: Sendable {
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
        /// - Returns: The computed segment count, ensuring a minimum of 5 segments.
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
        /// segment length. This method ensures a minimum of 5 segments for reasonable quality.
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

    /// Accesses the current segmentation settings from the environment.
    ///
    /// If not explicitly set, this defaults to `Segmentation.defaults`.
    var segmentation: Segmentation {
        get { self[Self.environmentKey] as? Segmentation ?? .defaults }
        set { self[Self.environmentKey] = newValue }
    }

    /// Returns a modified environment with the specified segmentation strategy.
    ///
    /// - Parameter segmentation: The `Segmentation` value to apply.
    /// - Returns: A new environment with the updated segmentation configuration.
    func withSegmentation(_ segmentation: Segmentation) -> EnvironmentValues {
        setting(key: Self.environmentKey, value: segmentation)
    }

    /// Sets an adaptive segmentation strategy in the environment.
    ///
    /// - Parameters:
    ///   - minAngle: The minimum angle per segment.
    ///   - minSize: The minimum segment length.
    mutating func setSegmentation(minAngle: Angle, minSize: Double) {
        segmentation = .adaptive(minAngle: minAngle, minSize: minSize)
    }

    /// Sets a fixed segmentation strategy in the environment.
    ///
    /// - Parameter count: The number of segments to use (minimum 3).
    mutating func setSegmentation(count: Int) {
        segmentation = .fixed(count)
    }
}

public extension Geometry {
    internal func withSegmentation(_ segmentation: EnvironmentValues.Segmentation) -> D.Geometry {
        withEnvironment { $0.withSegmentation(segmentation) }
    }

    /// Applies an adaptive segmentation configuration to this geometry.
    ///
    /// This method enables dynamic adjustment of segment counts based on both angular resolution
    /// and linear size. It ensures smooth appearance while balancing performance and model size.
    ///
    /// - Parameters:
    ///   - minAngle: The minimum angular resolution per segment.
    ///   - minSize: The minimum length of each segment.
    /// - Returns: A new geometry using the specified adaptive segmentation strategy.

    func withSegmentation(minAngle: Angle, minSize: Double) -> D.Geometry {
        withSegmentation(.adaptive(minAngle: minAngle, minSize: minSize))
    }

    /// Applies a fixed segmentation configuration to this geometry.
    ///
    /// This method sets a fixed number of segments to use for approximating circular or curved geometry,
    /// regardless of size or curvature.
    ///
    /// - Parameter count: The number of segments to use per revolution (minimum 3).
    /// - Returns: A new geometry using the specified fixed segmentation strategy.

    func withSegmentation(count: Int) -> D.Geometry {
        withSegmentation(.fixed(count))
    }

    /// Applies the default segmentation configuration to this geometry.
    ///
    /// The default configuration uses an adaptive strategy with a reasonable balance
    /// between performance and visual quality.
    ///
    /// - Returns: A new geometry using the default segmentation setting.

    func withDefaultSegmentation() -> D.Geometry {
        withSegmentation(.defaults)
    }
}
