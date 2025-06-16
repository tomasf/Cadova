import Foundation

internal struct EnvironmentModifier<D: Dimensionality>: Geometry {
    let body: D.Geometry
    let modification: @Sendable (EnvironmentValues) -> EnvironmentValues

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        try await context.buildResult(for: body, in: modification(environment))
    }
}


public extension Geometry {
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
    func withEnvironment(_ modifier: @Sendable @escaping (EnvironmentValues) -> EnvironmentValues) -> D.Geometry {
        EnvironmentModifier(body: self, modification: modifier)
    }

    func withEnvironment(_ modifier: @Sendable @escaping (inout EnvironmentValues) -> ()) -> D.Geometry {
        EnvironmentModifier(body: self, modification: {
            var e = $0
            modifier(&e)
            return e
        })
    }

    func withEnvironment(key: EnvironmentValues.Key, value: (any Sendable)?) -> D.Geometry {
        withEnvironment { environment in
            environment.setting(key: key, value: value)
        }
    }

    internal func withEnvironment(_ environment: EnvironmentValues) -> D.Geometry {
        withEnvironment { _ in environment }
    }
}
