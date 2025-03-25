import Foundation

struct EnvironmentModifier<Geometry> {
    let body: Geometry
    let modification: (EnvironmentValues) -> EnvironmentValues

    func modifiedEnvironment(_ environment: EnvironmentValues) -> EnvironmentValues {
        modification(environment)
    }
}

extension EnvironmentModifier<any Geometry2D>: Geometry2D {
    func evaluated(in environment: EnvironmentValues) -> Output2D {
        body.evaluated(in: modifiedEnvironment(environment))
    }
}

extension EnvironmentModifier<any Geometry3D>: Geometry3D {
    func evaluated(in environment: EnvironmentValues) -> Output3D {
        body.evaluated(in: modifiedEnvironment(environment))
    }
}


public extension Geometry2D {
    /// Applies a specified environment modification to this geometry, affecting its appearance or behavior.
    ///
    /// Use this method to modify the environment for this geometry. The modification is applied by a closure that you provide, which can set or modify any environment settings such as custom environment values you've added.
    ///
    /// Example usage:
    /// ```
    /// myGeometry.withEnvironment { environment in
    ///     environment.setting(key: myCustomKey, value: "newValue")
    /// }
    /// ```
    ///
    /// - Parameter modifier: A closure that takes the current `EnvironmentValues` and returns the modified `EnvironmentValues`.
    /// - Returns: A new geometry with the modified environment settings applied.
    func withEnvironment(_ modifier: @escaping (EnvironmentValues) -> EnvironmentValues) -> any Geometry2D {
        EnvironmentModifier(body: self, modification: modifier)
    }

    func withEnvironment(key: EnvironmentValues.Key, value: (any Sendable)?) -> any Geometry2D {
        withEnvironment { environment in
            environment.setting(key: key, value: value)
        }
    }

    internal func withEnvironment(_ environment: EnvironmentValues) -> any Geometry2D {
        withEnvironment { _ in environment }
    }
}

public extension Geometry3D {
    /// Applies a specified environment modification to this geometry, affecting its appearance or behavior.
    ///
    /// Use this method to modify the environment for this geometry. The modification is applied by a closure that you provide, which can set or modify any environment settings such as custom environment values you've added.
    ///
    /// Example usage:
    /// ```
    /// myGeometry.withEnvironment { environment in
    ///     environment.setting(key: myCustomKey, value: "newValue")
    /// }
    /// ```
    ///
    /// - Parameter modifier: A closure that takes the current `EnvironmentValues` and returns the modified `EnvironmentValues`.
    /// - Returns: A new geometry with the modified environment settings applied.
    func withEnvironment(_ modifier: @escaping (EnvironmentValues) -> EnvironmentValues) -> any Geometry3D {
        EnvironmentModifier(body: self, modification: modifier)
    }

    func withEnvironment(key: EnvironmentValues.Key, value: (any Sendable)?) -> any Geometry3D {
        withEnvironment { environment in
            environment.setting(key: key, value: value)
        }
    }

    internal func withEnvironment(_ environment: EnvironmentValues) -> any Geometry3D {
        withEnvironment { _ in environment }
    }
}
