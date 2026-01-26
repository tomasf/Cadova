import Foundation

extension [BuildDirective] {
    func build(
        with options: ModelOptions,
        in environment: EnvironmentValues,
        context: EvaluationContext
    ) async throws -> (OutputDataProvider, [BuildWarning]) {
        let geometries3D = compactMap(\.geometry3D)
        let geometries2D = compactMap(\.geometry2D)

        if geometries3D.count > 0 {
            let promotedFrom2D = geometries2D.map { $0.promotedTo3D() }
            let result = try await context.buildModelResult(for: Union(geometries3D + promotedFrom2D), in: environment)
            return (options.dataProvider(for: result), result.buildWarnings)

        } else if geometries2D.count > 0 {
            let result = try await context.buildModelResult(for: Union(geometries2D), in: environment)
            return (options.dataProvider(for: result), result.buildWarnings)

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
            builder(&mutatingEnvironment)
        }
        if let modelOptions {
            mutatingEnvironment.modelOptions = modelOptions
        }
        return mutatingEnvironment
    }
}

internal protocol ModelBuildable: Sendable {
    func build(
        environment inheritedEnvironment: EnvironmentValues,
        context: EvaluationContext,
        options inheritedOptions: ModelOptions?,
        URL directory: URL?
    ) async -> [URL]
}
