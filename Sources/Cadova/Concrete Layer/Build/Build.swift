import Foundation

extension [BuildDirective] {
    func build(
        with options: ModelOptions,
        in environment: EnvironmentValues,
        context: EvaluationContext
    ) async throws -> (provider: OutputDataProvider, warnings: [BuildWarning], parameters: [ParameterDescriptor]) {
        let geometries3D = compactMap(\.geometry3D)
        let geometries2D = compactMap(\.geometry2D)

        if geometries3D.count > 0 {
            let promotedFrom2D = geometries2D.map { $0.promotedTo3D() }
            let result = try await context.buildModelResult(for: Union(geometries3D + promotedFrom2D), in: environment)
            return (options.dataProvider(for: result, in: environment), result.buildWarnings, result.elements[ParameterList.self].parameters)

        } else if geometries2D.count > 0 {
            let result = try await context.buildModelResult(for: Union(geometries2D), in: environment)
            return (options.dataProvider(for: result, in: environment), result.buildWarnings, result.elements[ParameterList.self].parameters)

        } else {
            throw BuildError.noGeometry
        }
    }
}

enum BuildError: Error {
    case noGeometry
}

fileprivate extension Geometry2D {
    func promotedTo3D() -> any Geometry3D {
        extruded(height: 0.001)
    }
}

internal extension EnvironmentValues {
    func adding(directives: [BuildDirective], modelOptions: ModelOptions? = nil) -> Self {
        var mutatingEnvironment = self
        for builder in directives.compactMap(\.environment) {
            // Current while the directive runs, so what it reads from the environment, such as a
            // customizer's parameter values, comes from the model it's in
            mutatingEnvironment.whileCurrent {
                builder(&mutatingEnvironment)
            }
        }
        if let modelOptions {
            mutatingEnvironment.modelOptions = modelOptions
        }
        return mutatingEnvironment
    }
}

internal protocol ModelBuildable: Sendable {
    /// Builds and writes everything this buildable contains, returning how much of it failed.
    ///
    /// Never throws. One model failing must not cancel the rest of the build, so each failure is
    /// logged where it happens and counted here, for the `Project` at the top to act on.
    func build(
        environment inheritedEnvironment: EnvironmentValues,
        context: EvaluationContext,
        options inheritedOptions: ModelOptions?,
        URL directory: URL?,
        filterPath: [String]
    ) async -> Int
}
