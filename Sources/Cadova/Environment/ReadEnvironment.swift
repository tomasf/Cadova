import Foundation

struct EnvironmentReader<D: Dimensionality>: Geometry {
    let body: @Sendable (EnvironmentValues) -> D.Geometry

    func build(in environment: EnvironmentValues, context: EvaluationContext) async -> D.Result {
        await body(environment).build(in: environment, context: context)
    }
}

/// Creates a geometry that can read and respond to the current environment settings.
///
/// Use this function to create a geometry that has access to environmental information. This allows for dynamic and conditional geometry creation based on the current environment settings such as facets, text settings, or custom values you've defined.
///
/// - Parameter body: A closure that takes the current `EnvironmentValues` and returns a new `Geometry2D` instance based on that environment.
/// - Returns: A geometry instance that can be dynamically created based on the current environment.
public func readEnvironment<D: Dimensionality>(
    @GeometryBuilder<D> _ body: @Sendable @escaping (EnvironmentValues) -> D.Geometry
) -> D.Geometry {
    EnvironmentReader(body: body)
}

/// Creates a geometry that reads a specific environment value and adjusts its geometry accordingly.
///
/// This overload reads one specific key path from the environment and uses it within the body to create `Geometry2D`.
/// - Parameters:
///   - keyPath1: A key path to the specific value in `EnvironmentValues` used in geometry creation.
///   - body: A closure that takes the specified environment value and returns a `Geometry` instance based on that value.
/// - Returns: A dynamically created geometry instance that responds to the specified environment value.
public func readEnvironment<D: Dimensionality, T>(
    _ keyPath1: KeyPath<EnvironmentValues, T>,
    @GeometryBuilder<D> _ body: @Sendable @escaping (T) -> D.Geometry
) -> D.Geometry {
    readEnvironment {
        body($0[keyPath: keyPath1])
    }
}

/// Creates a geometry that reads two specific environment values and adjusts its geometry accordingly.
///
/// This overload reads two specific key paths from the environment and uses them to inform the body closure’s geometry creation.
/// - Parameters:
///   - keyPath1: A key path to the first specific value in `EnvironmentValues`.
///   - keyPath2: A key path to the second specific value in `EnvironmentValues`.
///   - body: A closure that takes the two specified environment values and returns a `Geometry` instance based on them.
/// - Returns: A geometry instance dynamically created based on the specified environment values.
public func readEnvironment<D: Dimensionality, T, U>(
    _ keyPath1: KeyPath<EnvironmentValues, T>,
    _ keyPath2: KeyPath<EnvironmentValues, U>,
    @GeometryBuilder<D> _ body: @Sendable @escaping (T, U) -> D.Geometry
) -> D.Geometry {
    readEnvironment {
        body($0[keyPath: keyPath1], $0[keyPath: keyPath2])
    }
}

/// Creates a geometry that reads three specific environment values and adjusts its geometry accordingly.
///
/// This overload reads three specific key paths from the environment and uses them to inform the body closure’s geometry creation.
/// - Parameters:
///   - keyPath1: A key path to the first specific value in `EnvironmentValues`.
///   - keyPath2: A key path to the second specific value in `EnvironmentValues`.
///   - keyPath3: A key path to the third specific value in `EnvironmentValues`.
///   - body: A closure that takes the three specified environment values and returns a `Geometry` instance based on them.
/// - Returns: A geometry instance dynamically created based on the specified environment values.
public func readEnvironment<D: Dimensionality, T, U, V>(
    _ keyPath1: KeyPath<EnvironmentValues, T>,
    _ keyPath2: KeyPath<EnvironmentValues, U>,
    _ keyPath3: KeyPath<EnvironmentValues, V>,
    @GeometryBuilder<D> _ body: @Sendable @escaping (T, U, V) -> D.Geometry
) -> D.Geometry {
    readEnvironment {
        body($0[keyPath: keyPath1], $0[keyPath: keyPath2], $0[keyPath: keyPath3])
    }
}
