import Foundation

public extension EnvironmentValues {
    private static let key = Key("Cadova.Tolerance")

    /// The tolerance value currently set in the environment.
    ///
    /// This property retrieves the tolerance setting from the environment. If not explicitly set, the tolerance
    /// defaults to 0. Tolerance can be understood as the permissible limit or limits of variation in measurements,
    /// dimensions, or physical properties of a geometry. While the tolerance value itself does not directly influence
    /// geometry creation in Cadova, it can be utilized by your own models to adjust generation of geometries according
    /// to the specified tolerance.
    ///
    /// - Returns: The current tolerance value as a `Double`.
    ///
    var tolerance: Double {
        get { self[Self.key] as? Double ?? 0 }
        set { self[Self.key] = newValue }
    }

    /// Set the tolerance value
    ///
    /// This method modifies the tolerance setting of an environment. Tolerance can be understood as the permissible
    /// limit or limits of variation in measurements, dimensions, or physical properties of a geometry. While the
    /// tolerance value itself does not directly influence geometry creation in Cadova, it can be utilized by your own
    /// models to adjust generation of geometries according to the specified tolerance.
    ///
    /// - Returns: A new environment with a modified tolerance
    ///
    func withTolerance(_ tolerance: Double) -> EnvironmentValues {
        setting(key: Self.key, value: tolerance)
    }
}

public extension Geometry {
    /// Applies a specified tolerance setting to the geometry.
    ///
    /// This method allows setting a tolerance value for the geometry, which your own code or third-party libraries can
    /// interpret and use to adjust their processing or validation logic. Cadova itself does not use this value to
    /// modify geometry creation or dimensions.
    ///
    /// - Parameter tolerance: The tolerance value to set for the geometry.
    /// - Returns: A modified geometry with the specified tolerance setting applied.
    ///
    func withTolerance(_ tolerance: Double) -> D.Geometry {
        withEnvironment { enviroment in
            enviroment.withTolerance(tolerance)
        }
    }
}

/// Reads the current tolerance from the environment and uses it to construct geometry.
///
/// This function retrieves the `tolerance` value currently set in the environment and passes it
/// to the provided builder closure. You can use this to make geometry that adapts its shape or
/// precision based on a configured tolerance level.
///
/// While Cadova itself does not interpret the tolerance value, this can be used by your own models
/// or logic to influence geometry construction.
///
/// - Parameter reader: A closure that receives the current tolerance value and returns a geometry built with it.
/// - Returns: The geometry produced by the closure using the current tolerance setting.
///
public func readTolerance<D: Dimensionality>(
    @GeometryBuilder<D> _ reader: @Sendable @escaping (Double) -> D.Geometry
) -> D.Geometry {
    readEnvironment { e in
        reader(e.tolerance)
    }
}
