import Foundation

internal extension EnvironmentValues {
    /// A tolerance together with the scale of the coordinate system it was set in.
    ///
    /// Storing the scale is what lets ``EnvironmentValues/tolerance`` be re-expressed for each reader, so that a
    /// clearance keeps meaning the same physical size in the coordinate system where it was written, no matter what
    /// transforms are applied above or below it.
    ///
    struct ToleranceData: Sendable {
        let tolerance: Double
        let scale: Double

        static let standard = Self(tolerance: 0, scale: 1)

        /// Re-expresses the tolerance in the given environment's coordinate system.
        func tolerance(in environment: EnvironmentValues) -> Double {
            environment.length(tolerance, definedAtScale: scale)
        }
    }

    var toleranceData: ToleranceData {
        self[Self.toleranceKey] as? ToleranceData ?? .standard
    }
}

public extension EnvironmentValues {
    static fileprivate let toleranceKey = Key("Cadova.Tolerance")

    /// The tolerance value currently set in the environment.
    ///
    /// Tolerance can be understood as the permissible limit or limits of variation in measurements, dimensions, or
    /// physical properties of a geometry. While the tolerance value itself does not directly influence geometry
    /// creation in Cadova, it can be utilized by your own models to adjust generation of geometries according to the
    /// specified tolerance.
    ///
    /// Like segmentation, the tolerance is a length, and is expressed in the coordinate system it is set in. Reading it
    /// from a coordinate system that has been scaled since then returns the equivalent clearance for that system, so
    /// the fit it describes is the same either way. Setting it and immediately reading it back always gives you the
    /// value you set.
    ///
    /// If not explicitly set, this defaults to 0.
    ///
    /// - Returns: The current tolerance value as a `Double`.
    ///
    var tolerance: Double {
        get { toleranceData.tolerance(in: self) }
        set { self[Self.toleranceKey] = ToleranceData(tolerance: newValue, scale: scale) }
    }

    /// Set the tolerance value
    ///
    /// This method modifies the tolerance setting of an environment. Tolerance can be understood as the permissible
    /// limit or limits of variation in measurements, dimensions, or physical properties of a geometry. While the
    /// tolerance value itself does not directly influence geometry creation in Cadova, it can be utilized by your own
    /// models to adjust generation of geometries according to the specified tolerance.
    ///
    /// The tolerance is interpreted in this environment's current coordinate system.
    ///
    /// - Returns: A new environment with a modified tolerance
    ///
    func withTolerance(_ tolerance: Double) -> EnvironmentValues {
        var environment = self
        environment.tolerance = tolerance
        return environment
    }
}

public extension Geometry {
    /// Applies a specified tolerance setting to the geometry.
    ///
    /// This method allows setting a tolerance value for the geometry, which your own code or third-party libraries can
    /// interpret and use to adjust their processing or validation logic. Cadova itself does not use this value to
    /// modify geometry creation or dimensions.
    ///
    /// The tolerance is expressed in the coordinate system this modifier is applied in. If the geometry is scaled
    /// further out in the chain, the tolerance scales with it, so the fit it describes is unaffected.
    ///
    /// - Parameter tolerance: The tolerance value to set for the geometry.
    /// - Returns: A modified geometry with the specified tolerance setting applied.
    ///
    func withTolerance(_ tolerance: Double) -> D.Geometry {
        withEnvironment { environment in
            environment.withTolerance(tolerance)
        }
    }
}
