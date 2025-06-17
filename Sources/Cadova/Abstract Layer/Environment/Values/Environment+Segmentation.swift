import Foundation

public extension EnvironmentValues {
    static private let environmentKey = Key("Cadova.Segmentation")

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
    internal func withSegmentation(_ segmentation: Segmentation) -> D.Geometry {
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
