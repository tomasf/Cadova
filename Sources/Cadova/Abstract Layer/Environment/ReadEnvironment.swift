import Foundation

struct EnvironmentReader<D: Dimensionality>: Geometry {
    let body: @Sendable (EnvironmentValues) -> D.Geometry

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        try await context.buildResult(for: body(environment), in: environment)
    }
}

/// Creates a geometry that can read and respond to the current environment settings.
///
/// Use this function to create a geometry that has access to environmental information. This allows for dynamic and
/// conditional geometry creation based on the current environment settings such as segmentation, tolerance, or custom
/// values you've defined.
///
/// - Parameter body: A closure that takes the current `EnvironmentValues` and returns a new geometry instance
///   based on that environment.
/// - Returns: A geometry instance that can be dynamically created based on the current environment.
///
public func readEnvironment<D: Dimensionality>(
    @GeometryBuilder<D> _ body: @Sendable @escaping (EnvironmentValues) -> D.Geometry
) -> D.Geometry {
    EnvironmentReader(body: body)
}

/// Creates a geometry that reads specific environment values and adjusts its geometry accordingly.
///
/// This overload reads specific key paths from the environment and uses them within the body to create geometry.
/// - Parameters:
///   - keyPaths: A variadic list of key paths to specific values in `EnvironmentValues` used in geometry creation.
///   - body: A closure that takes the specified environment values and returns geometry based on those values.
/// - Returns: A dynamically created geometry instance that responds to the specified environment values.
///
public func readEnvironment<D: Dimensionality, each EachValue>(
    _ keyPaths: repeat KeyPath<EnvironmentValues, each EachValue>,
    @GeometryBuilder<D> body: @Sendable @escaping (repeat each EachValue) -> D.Geometry
) -> D.Geometry {
    // localKeyPaths is needed due to a Swift bug. Should get fixed by https://github.com/swiftlang/swift/pull/80220
    let localKeyPaths = (repeat each keyPaths)
    return readEnvironment { environment in
        body(repeat environment[keyPath: each localKeyPaths])
    }
}

extension Geometry {
    /// Modifies this geometry by reading the current environment values.
    ///
    /// Use this modifier when you want to adjust an existing geometry in response to the environment.
    /// - Parameter body: A closure that takes the current `EnvironmentValues` and returns a modified version of
    ///   this geometry.
    /// - Returns: A new geometry modified according to the environment.
    ///
    public func readingEnvironment(
        @GeometryBuilder<D> _ body: @Sendable @escaping (D.Geometry, EnvironmentValues) -> D.Geometry
    ) -> D.Geometry {
        readEnvironment { env in
            body(self, env)
        }
    }

    /// Modifies this geometry by reading specific environment values.
    ///
    /// This overload allows you to specify exactly which environment values to read using key paths.
    /// The geometry is then modified using the current values of those keys.
    ///
    /// - Parameters:
    ///   - keyPaths: A variadic list of key paths into `EnvironmentValues` that this geometry depends on.
    ///   - body: A closure that takes the current geometry and the specified environment values to return a modified geometry.
    /// - Returns: A new geometry adjusted according to the specified environment values.
    ///
    public func readingEnvironment<each EachValue>(
        _ keyPaths: repeat KeyPath<EnvironmentValues, each EachValue>,
        @GeometryBuilder<D> body: @Sendable @escaping (D.Geometry, repeat each EachValue) -> D.Geometry
    ) -> D.Geometry {
        return readEnvironment(repeat each keyPaths) { (values: repeat each EachValue) in
            body(self, repeat each values)
        }
    }
}
