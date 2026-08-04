import Foundation

/// Builds one input geometry (or several), then applies an arbitrary transformation directly to
/// the resulting node(s) — possibly changing dimensionality in the process (e.g. an extrusion
/// turning a 2D node into a 3D one). Used to implement operations that need to manipulate the
/// underlying `GeometryNode` tree directly rather than composing existing `Geometry` values.
struct GeometryNodeTransformer<Input: Dimensionality, D: Dimensionality>: Geometry {
    let transformer: @Sendable (EnvironmentValues, EvaluationContext) async throws -> BuildResult<D>

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

    func _build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> BuildResult<D> {
        try await transformer(environment, context)
    }
}
