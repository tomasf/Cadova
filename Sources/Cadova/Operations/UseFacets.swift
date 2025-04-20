import Foundation
import Manifold3D

public extension Geometry {
    /// Applies a segmentation strategy to this geometry.
    ///
    /// This method sets the segmentation behavior for how circular or curved features
    /// are approximated using linear segments. The segmentation setting is stored in the environment
    /// and can be read by geometric primitives to adjust their level of detail.
    ///
    /// - Parameter segmentation: The segmentation strategy to apply.
    /// - Returns: A new geometry with the specified segmentation setting.

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
