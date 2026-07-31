import Foundation

struct Hidden<D: Dimensionality>: Geometry {
    let body: D.Geometry

    func _build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        let bodyResult = try await context.buildResult(for: body, in: environment)
        return bodyResult.replacing(node: .empty)
    }
}

public extension Geometry {
    func hidden() -> D.Geometry {
        Hidden<D>(body: self)
    }
}

struct GeometryNodeTransformer<Input: Dimensionality, D: Dimensionality>: Geometry {
    let transformer: @Sendable (EnvironmentValues, EvaluationContext) async throws -> D.BuildResult

    init(
        body: Input.Geometry,
        nodeTransformer: @Sendable @escaping (Input.Node) throws -> D.Node,
        environment environmentTransformer: (@Sendable (EnvironmentValues) -> EnvironmentValues)? = nil
    ) {
        transformer = { environment, context in
            let newEnvironment = environmentTransformer?(environment) ?? environment
            let bodyResult = try await context.buildResult(for: body, in: newEnvironment)
            return bodyResult.replacing(node: try nodeTransformer(bodyResult.node))
        }
    }

    init(
        bodies: [Input.Geometry],
        nodeTransformer: @Sendable @escaping ([Input.Node]) -> D.Node
    ) {
        transformer = { environment, context in
            let results = try await bodies.asyncMap { try await context.buildResult(for: $0, in: environment) }
            let node = nodeTransformer(results.map(\.node))
            return .init(node: node, elements: .init(combining: results.map(\.elements)))
        }
    }

    func _build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        try await transformer(environment, context)
    }
}
