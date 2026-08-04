import Foundation

/// Builds `source`, then applies an arbitrary transformation to its resulting node — possibly
/// changing dimensionality in the process (e.g. 2D to 3D). The transformed node is cached by the
/// combination of `source`'s built node and `key`, so the transformation only reruns when either
/// changes.
struct CachedNodeTransformer<D: Dimensionality, Input: Dimensionality>: Geometry {
    let source: Input.Geometry
    let key: LabeledCacheKey
    let generator: @Sendable (Input.Node, EnvironmentValues, EvaluationContext) async throws -> D.Node

    init(
        source: Input.Geometry,
        name: String,
        parameters: any CacheKey...,
        generator: @Sendable @escaping (Input.Node, EnvironmentValues, EvaluationContext) async throws -> D.Node
    ) {
        self.source = source
        self.key = LabeledCacheKey(operationName: name, parameters: parameters)
        self.generator = generator
    }

    func _build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> BuildResult<D> {
        let bodyResult = try await context.buildResult(for: source, in: environment)
        let bakedKey = NodeCacheKey(base: key, node: bodyResult.node)

        return try await context.materializedResult(buildResult: bodyResult, key: bakedKey) {
            let outputNode = try await generator(bodyResult.node, environment, context)
            return try await context.result(for: outputNode)
        }
    }
}
