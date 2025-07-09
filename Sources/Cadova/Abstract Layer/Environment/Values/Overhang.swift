import Foundation

public extension EnvironmentValues {
    private static let key = Key("Cadova.OverhangAngle")

    /// The overhang angle currently set in the environment.
    ///
    /// This property retrieves the overhang angle setting from the environment. If not explicitly set, the overhang
    /// defaults to 45°. Overhang is typically defined as the maximum angle from the vertical at which material can be
    /// printed without requiring support, a common concept in 3D printing. This value can be used by your own code or
    /// by Cadova features such as overhang-safe circular geometry to influence geometry generation according to the
    /// specified overhang constraint.
    ///
    /// - Returns: The current overhang value as an `Angle`.
    var overhangAngle: Angle {
        get { self[Self.key] as? Angle ?? 45° }
        set { self[Self.key] = newValue }
    }

    /// Sets the overhang angle value for this environment.
    ///
    /// - Parameter angle: The new overhang value to set.
    /// - Returns: A new environment with the specified overhang value set.
    func withOverhangAngle(_ angle: Angle) -> EnvironmentValues {
        precondition(angle > 0° && angle <= 90°, "Overhang angle must be between 0 and 90 degrees")
        return setting(key: Self.key, value: angle)
    }
}

public extension Geometry {
    /// Applies a specified overhang angle setting to the geometry.
    ///
    /// This method allows you to set an overhang angle for the geometry, which your own code or third-party libraries
    /// can interpret and use to adjust their processing or validation logic. Cadova itself uses this for overhang-safe
    /// circular geometry.
    ///
    /// - Parameter angle: The overhang angle to set for the geometry.
    /// - Returns: A modified geometry with the specified overhang setting applied.
    func withOverhangAngle(_ angle: Angle) -> D.Geometry {
        withEnvironment { enviroment in
            enviroment.withOverhangAngle(angle)
        }
    }
}
