import Foundation

internal extension EnvironmentValues {
    /// A simplification threshold together with the scale of the coordinate system it was set in.
    ///
    /// Storing the scale is what lets ``EnvironmentValues/simplificationThreshold`` be re-expressed for each reader,
    /// so that the smallest detail worth keeping stays the same physical size in the coordinate system where it was
    /// written, no matter what transforms are applied above or below it.
    ///
    struct SimplificationThresholdData: Sendable {
        let threshold: Double
        let scale: Double

        static let standard = Self(threshold: 0.005, scale: 1)

        /// Re-expresses the threshold in the given environment's coordinate system.
        func threshold(in environment: EnvironmentValues) -> Double {
            environment.length(threshold, definedAtScale: scale)
        }
    }

    var simplificationThresholdData: SimplificationThresholdData {
        self[Self.simplificationThresholdKey] as? SimplificationThresholdData ?? .standard
    }
}

public extension EnvironmentValues {
    static fileprivate let simplificationThresholdKey = Key("Cadova.SimplificationThreshold")

    /// The simplification threshold currently set in the environment.
    ///
    /// This threshold controls how aggressively certain Cadova operations (like wrapping and twisting)
    /// simplify their resulting geometry by merging nearby vertices. The goal of simplification is to
    /// create lighter, more efficient geometry that is faster to process and manipulate, not to improve
    /// the visual appearance — in fact, it may slightly degrade uniformity to achieve better performance.
    ///
    /// - A lower value preserves more geometric detail.
    /// - A higher value simplifies more aggressively.
    ///
    /// The threshold is a distance, and like segmentation and tolerance it is expressed in the coordinate system it
    /// is set in. Reading it from a coordinate system that has been scaled since then returns the equivalent
    /// threshold for that system, so the same detail survives either way. Setting it and immediately reading it back
    /// always gives you the value you set.
    ///
    /// The default threshold is `0.005`. Setting the threshold to `0` disables automatic simplification entirely.
    ///
    /// Note: Simplification is only applied to selected operations where appropriate, not universally
    /// across all geometry.
    ///
    var simplificationThreshold: Double {
        get { simplificationThresholdData.threshold(in: self) }
        set { self[Self.simplificationThresholdKey] = SimplificationThresholdData(threshold: newValue, scale: scale) }
    }

    /// Sets the simplification threshold.
    ///
    /// The threshold is interpreted in this environment's current coordinate system.
    ///
    /// - Parameter threshold: The simplification threshold to apply. Set to `0` to disable simplification, or `nil`
    ///   to restore the default.
    /// - Returns: A new environment with the specified simplification threshold.
    func withSimplificationThreshold(_ threshold: Double?) -> EnvironmentValues {
        guard let threshold else {
            return setting(key: Self.simplificationThresholdKey, value: nil)
        }
        var environment = self
        environment.simplificationThreshold = threshold
        return environment
    }
}

public extension Geometry {
    /// Applies a specified simplification threshold to the geometry.
    ///
    /// Some operations in Cadova, such as wrapping and twisting, may apply automatic simplification
    /// to reduce the number of vertices and produce more lightweight, efficient geometry that is less
    /// expensive to process. Simplification does not aim to improve the visual appearance — in fact,
    /// it may slightly degrade uniformity — but helps optimize performance, especially for complex models.
    ///
    /// The threshold represents the maximum distance within which nearby vertices can be merged or simplified.
    /// A smaller threshold preserves more geometric detail, while a larger threshold results in simpler geometry
    /// with fewer vertices. It is expressed in the coordinate system this modifier is applied in, so scaling the
    /// geometry afterwards scales the threshold with it and the same detail survives.
    ///
    /// If no custom threshold is set, the default value is `0.005`.
    /// Setting the threshold to `0` disables automatic simplification entirely.
    ///
    /// Note that simplification is applied only to specific operations in Cadova where it is appropriate,
    /// not to all geometry generation.
    ///
    /// - Parameter threshold: The simplification threshold to apply. Set to `0` to disable simplification.
    /// - Returns: A new geometry with the specified simplification threshold applied.
    func withSimplificationThreshold(_ threshold: Double) -> D.Geometry {
        withEnvironment {
            $0.withSimplificationThreshold(threshold)
        }
    }

    /// Restores the default simplification threshold.
    ///
    /// Removes any explicitly set threshold and reverts back to the default value (`0.005`).
    ///
    /// - Returns: A new geometry using the default simplification threshold.
    func withDefaultSimplificationThreshold() -> D.Geometry {
        withEnvironment {
            $0.withSimplificationThreshold(nil)
        }
    }
}
