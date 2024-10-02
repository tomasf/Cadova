import Foundation

struct EnvironmentModifier2D: Geometry2D {
    let body: any Geometry2D
    let modification: (Environment) -> Environment

    func codeFragment(in environment: Environment) -> CodeFragment {
        body.codeFragment(in: modifiedEnvironment(environment))
    }

    func boundary(in environment: Environment) -> Bounds {
        body.boundary(in: modifiedEnvironment(environment))
    }

    func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        body.elements(in: modifiedEnvironment(environment))
    }

    private func modifiedEnvironment(_ environment: Environment) -> Environment {
        modification(environment)
    }
}

struct EnvironmentModifier3D: Geometry3D {
    let body: any Geometry3D
    let modification: (Environment) -> Environment

    func codeFragment(in environment: Environment) -> CodeFragment {
        body.codeFragment(in: modifiedEnvironment(environment))
    }

    func boundary(in environment: Environment) -> Bounds {
        body.boundary(in: modifiedEnvironment(environment))
    }

    func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        body.elements(in: modifiedEnvironment(environment))
    }

    private func modifiedEnvironment(_ environment: Environment) -> Environment {
        modification(environment)
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
    /// - Parameter modifier: A closure that takes the current `Environment` and returns the modified `Environment`.
    /// - Returns: A new geometry with the modified environment settings applied.
    func withEnvironment(_ modifier: @escaping (Environment) -> Environment) -> any Geometry2D {
        EnvironmentModifier2D(body: self, modification: modifier)
    }

    func withEnvironment(key: Environment.ValueKey, value: (any Sendable)?) -> any Geometry2D {
        withEnvironment { environment in
            environment.setting(key: key, value: value)
        }
    }

    internal func withEnvironment(_ environment: Environment) -> any Geometry2D {
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
    /// - Parameter modifier: A closure that takes the current `Environment` and returns the modified `Environment`.
    /// - Returns: A new geometry with the modified environment settings applied.
    func withEnvironment(_ modifier: @escaping (Environment) -> Environment) -> any Geometry3D {
        EnvironmentModifier3D(body: self, modification: modifier)
    }

    func withEnvironment(key: Environment.ValueKey, value: (any Sendable)?) -> any Geometry3D {
        withEnvironment { environment in
            environment.setting(key: key, value: value)
        }
    }

    internal func withEnvironment(_ environment: Environment) -> any Geometry3D {
        withEnvironment { _ in environment }
    }
}
