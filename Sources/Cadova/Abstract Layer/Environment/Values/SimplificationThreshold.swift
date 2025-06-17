import Foundation

public extension EnvironmentValues {
    private static let key = Key("Cadova.SimplificationThreshold")
    private static let defaultThreshold: Double = 0.005

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
    /// The default threshold is `0.005`. Setting the threshold to `0` disables automatic simplification entirely.
    ///
    /// Note: Simplification is only applied to selected operations where appropriate, not universally
    /// across all geometry.
    ///
    var simplificationThreshold: Double {
        get { self[Self.key] as? Double ?? Self.defaultThreshold }
        set { self[Self.key] = newValue }
    }

    /// Sets the simplification threshold.
    ///
    /// - Parameter threshold: The simplification threshold to apply. Set to `0` to disable simplification.
    /// - Returns: A new environment with the specified simplification threshold.
    func withSimplificationThreshold(_ threshold: Double?) -> EnvironmentValues {
        setting(key: Self.key, value: threshold)
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
    /// with fewer vertices.
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
