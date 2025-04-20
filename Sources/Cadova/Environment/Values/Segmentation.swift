import Foundation

public extension EnvironmentValues {
    static private let environmentKey = Key("Cadova.Segmentation")

    /// An enumeration representing the method for calculating the number of segments (facets) used in rendering circular and curved geometries.

    enum Segmentation: Sendable {
        /// Specifies a fixed number of segments for circles, regardless of size.
        case fixed (Int)

        /// Specifies a dynamic calculation of segments based on the minimum angle and minimum size.
        /// - Parameters:
        ///   - minAngle: The minimum angle (in degrees) between segments.
        ///   - minSize: The minimum size of a segment.
        case adaptive (minAngle: Angle, minSize: Double)

        /// The default segmentation for Cadova, aiming for higher detail in rendered geometries.
        public static let defaults = Segmentation.adaptive(minAngle: 2°, minSize: 0.15)

        /// Calculates the number of segments for a circle based on its radius
        ///
        /// For `adaptive`, it calculates the appropriate number of segments based on the minimum angle and size.
        /// - Parameter r: The radius of the circle.
        /// - Returns: The calculated number of segments for a full circle.
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

        /// Calculates the number of segments for an item based on its length
        ///
        /// For `adaptive`, it calculates the appropriate number of segments based on the minimum size
        /// - Parameter length: The total length
        /// - Returns: The calculated number of segments
        ///
        public func segmentCount(length: Double) -> Int {
            switch self {
            case .fixed (let count):
                return max(count, 3)

            case .adaptive(_, let minSize):
                return Int(ceil(min(length / minSize, 5)))
            }
        }
    }

    /// Accesses the current segmentation settings from the environment.
    var segmentation: Segmentation {
        get { self[Self.environmentKey] as? Segmentation ?? .defaults }
        set { self[Self.environmentKey] = newValue }
    }

    mutating func setSegmentation(minAngle: Angle, minSize: Double) {
        segmentation = .adaptive(minAngle: minAngle, minSize: minSize)
    }

    mutating func setSegmentation(count: Int) {
        segmentation = .fixed(count)
    }

    /// Returns a new environment with the specified segmentation applied.
    ///
    /// This method allows for precise control over the resolution of circular and curved geometries.
    /// - Parameter segmentation: The `Segmentation` setting to apply to the environment.
    /// - Returns: A new `EnvironmentValues` with the updated segmentation.
    func withSegmentation(_ segmentation: Segmentation) -> EnvironmentValues {
        setting(key: Self.environmentKey, value: segmentation)
    }
}
