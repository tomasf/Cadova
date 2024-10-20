import Foundation

public extension Environment {
    private static let key = ValueKey("SwiftSCAD.Tolerance")

    /// The tolerance value currently set in the environment.
    ///
    /// This property retrieves the tolerance setting from the environment. If not explicitly set, the tolerance defaults to 0. Tolerance can be understood as the permissible limit or limits of variation in measurements, dimensions, or physical properties of a geometry. While the tolerance value itself does not directly influence geometry creation in SwiftSCAD, it can be utilized by your own models to adjust generation of geometries according to the specified tolerance.
    ///
    /// - Returns: The current tolerance value as a `Double`.
    var tolerance: Double {
        self[Self.key] as? Double ?? 0
    }

    /// Set the tolerance value
    ///
    /// This method modifies the tolerance setting of an environment. Tolerance can be understood as the permissible limit or limits of variation in measurements, dimensions, or physical properties of a geometry. While the tolerance value itself does not directly influence geometry creation in SwiftSCAD, it can be utilized by your own models to adjust generation of geometries according to the specified tolerance.
    ///
    /// - Returns: A new environment with a modified tolerance

    func withTolerance(_ tolerance: Double) -> Environment {
        setting(key: Self.key, value: tolerance)
    }
}

public extension Geometry3D {
    /// Applies a specified tolerance setting to the geometry.
    ///
    /// This method allows setting a tolerance value for the geometry, which your own code or third-party libraries can interpret and use to adjust their processing or validation logic. SwiftSCAD itself does not use this value to modify geometry creation or dimensions.
    ///
    /// - Parameter tolerance: The tolerance value to set for the geometry.
    /// - Returns: A modified geometry with the specified tolerance setting applied.
    func withTolerance(_ tolerance: Double) -> any Geometry3D {
        withEnvironment { enviroment in
            enviroment.withTolerance(tolerance)
        }
    }
}

public extension Geometry2D {
    /// Applies a specified tolerance setting to the geometry.
    ///
    /// This method allows setting a tolerance value for the geometry, which your own code or third-party libraries can interpret and use to adjust their processing or validation logic. SwiftSCAD itself does not use this value to modify geometry creation or dimensions.
    ///
    /// - Parameter tolerance: The tolerance value to set for the geometry.
    /// - Returns: A modified geometry with the specified tolerance setting applied.
    func withTolerance(_ tolerance: Double) -> any Geometry2D {
        withEnvironment { enviroment in
            enviroment.withTolerance(tolerance)
        }
    }
}

public func readTolerance(@GeometryBuilder2D _ reader: @escaping (Double) -> any Geometry2D) -> any Geometry2D {
    readEnvironment { e in
        reader(e.tolerance)
    }
}

public func readTolerance(@GeometryBuilder3D _ reader: @escaping (Double) -> any Geometry3D) -> any Geometry3D {
    readEnvironment { e in
        reader(e.tolerance)
    }
}
