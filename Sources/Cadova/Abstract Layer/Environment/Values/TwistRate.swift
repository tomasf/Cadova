import Foundation

public extension EnvironmentValues {
    private static let key = Key("Cadova.MaxTwistRate")
    private static let defaultValue = 2°

    /// The maximum twist rate allowed when sweeping a 2D shape along a 3D path.
    ///
    /// This value limits how quickly the orientation of the swept shape is allowed to change,
    /// expressed in angle per millimeter of path length. It helps prevent sharp visual twists
    /// or sudden changes in rotation, especially in regions where the path is perpendicular
    /// to the target direction or where alignment becomes ambiguous.
    ///
    /// The default value is `2°`, meaning the shape may rotate at most 2 degrees for every
    /// millimeter along the path. This can be overridden locally in a modeling context using
    /// `withMaxTwistRate(_:)`.
    var maxTwistRate: Angle {
        get { self[Self.key] as? Angle ?? Self.defaultValue }
        set { self[Self.key] = newValue }
    }

    /// Returns a copy of the environment with the specified twist rate applied.
    ///
    /// - Parameter value: The maximum allowable twist per millimeter of path length.
    /// - Returns: A new environment with the given twist rate.
    func withMaxTwistRate(_ value: Angle) -> EnvironmentValues {
        setting(key: Self.key, value: value)
    }
}

public extension Geometry {
    /// Apply a custom twist rate for sweeping operations.
    ///
    /// Use this modifier to set how quickly a swept shape is allowed to rotate along a path.
    /// This is useful for fine-tuning visual appearance or resolving artifacts in tight curves
    /// or when the path direction is poorly aligned with the reference target.
    ///
    /// ```swift
    /// Rectangle(5)
    ///   .swept(along: path)
    ///   .withMaxTwistRate(1°)
    /// ```
    ///
    /// - Parameter value: The maximum twist per millimeter.
    /// - Returns: A new geometry with the twist rate applied.
    ///
    func withMaxTwistRate(_ value: Angle) -> D.Geometry {
        withEnvironment { enviroment in
            enviroment.withMaxTwistRate(value)
        }
    }
}
