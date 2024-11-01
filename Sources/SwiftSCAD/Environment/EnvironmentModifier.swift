import Foundation

struct EnvironmentModifier<Geometry> {
    let body: Geometry
    let modification: (Environment) -> Environment

    func modifiedEnvironment(_ environment: Environment) -> Environment {
        modification(environment)
    }
}

extension EnvironmentModifier<any Geometry2D>: Geometry2D {
    func codeFragment(in environment: Environment) -> CodeFragment {
        body.codeFragment(in: modifiedEnvironment(environment))
    }

    func boundary(in environment: Environment) -> Boundary2D {
        body.boundary(in: modifiedEnvironment(environment))
    }

    func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        body.elements(in: modifiedEnvironment(environment))
    }
}

extension EnvironmentModifier<any Geometry3D>: Geometry3D {
    func codeFragment(in environment: Environment) -> CodeFragment {
        body.codeFragment(in: modifiedEnvironment(environment))
    }

    func boundary(in environment: Environment) -> Boundary3D {
        body.boundary(in: modifiedEnvironment(environment))
    }

    func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        body.elements(in: modifiedEnvironment(environment))
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
        EnvironmentModifier(body: self, modification: modifier)
    }

    func withEnvironment(key: Environment.Key, value: (any Sendable)?) -> any Geometry2D {
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
        EnvironmentModifier(body: self, modification: modifier)
    }

    func withEnvironment(key: Environment.Key, value: (any Sendable)?) -> any Geometry3D {
        withEnvironment { environment in
            environment.setting(key: key, value: value)
        }
    }

    internal func withEnvironment(_ environment: Environment) -> any Geometry3D {
        withEnvironment { _ in environment }
    }
}
