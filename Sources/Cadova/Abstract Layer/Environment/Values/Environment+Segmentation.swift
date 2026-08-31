import Foundation

internal extension EnvironmentValues {
    /// A segmentation setting together with the scale of the coordinate system it was set in.
    ///
    /// Storing the scale is what lets ``EnvironmentValues/segmentation`` be re-expressed for each reader, so that an
    /// adaptive `minSize` keeps meaning the same physical size in the coordinate system where it was written, no
    /// matter what transforms are applied above or below it.
    ///
    struct SegmentationData: Sendable {
        let segmentation: Segmentation
        let scale: Double

        static let standard = Self(segmentation: .defaults, scale: 1)

        /// Re-expresses the segmentation in a coordinate system with the given scale.
        func segmentation(at scale: Double) -> Segmentation {
            switch segmentation {
            case .fixed:
                segmentation
            case .adaptive(let minAngle, let minSize):
                .adaptive(minAngle: minAngle, minSize: minSize * self.scale / scale)
            }
        }
    }

    var segmentationData: SegmentationData {
        self[Self.segmentationKey] as? SegmentationData ?? .standard
    }
}

public extension EnvironmentValues {
    static fileprivate let segmentationKey = Key("Cadova.Segmentation")

    /// Accesses the current segmentation settings from the environment.
    ///
    /// Segmentation is expressed in the coordinate system it is set in. Reading it from a coordinate system that has
    /// been scaled since then returns the equivalent segmentation for that system, so the geometry it produces has the
    /// same shape either way. Setting it and immediately reading it back always gives you the value you set.
    ///
    /// If not explicitly set, this defaults to `Segmentation.defaults`, expressed in world space.
    ///
    var segmentation: Segmentation {
        get { segmentationData.segmentation(at: scale) }
        set {
            switch newValue {
            case .adaptive (let minAngle, let minSize):
                precondition(minAngle > 0° && minSize > 0)
            case .fixed (let count):
                precondition(count > 0)
            }
            self[Self.segmentationKey] = SegmentationData(segmentation: newValue, scale: scale)
        }
    }

    /// Returns a modified environment with the specified segmentation strategy.
    ///
    /// The segmentation is interpreted in this environment's current coordinate system.
    ///
    /// - Parameter segmentation: The `Segmentation` value to apply.
    /// - Returns: A new environment with the updated segmentation configuration.
    func withSegmentation(_ segmentation: Segmentation) -> EnvironmentValues {
        var environment = self
        environment.segmentation = segmentation
        return environment
    }

    /// Sets an adaptive segmentation strategy in the environment.
    ///
    /// - Parameters:
    ///   - minAngle: The minimum angle per segment.
    ///   - minSize: The minimum segment length, in the current coordinate system.
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
    /// `minSize` is expressed in the coordinate system this modifier is applied in. If the geometry is scaled
    /// further out in the chain, the segmentation scales with it, so the shape of the result is unaffected.
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
