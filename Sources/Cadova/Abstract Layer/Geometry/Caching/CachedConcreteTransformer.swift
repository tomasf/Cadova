import Foundation

/// Builds `body`, then applies an arbitrary transformation to its resulting concrete. The
/// transformed concrete is cached by the combination of `body`'s built node and `key`, so the
/// transformation only reruns when either changes.
struct CachedConcreteTransformer<D: Dimensionality, Key: CacheKey>: Geometry {
    let body: D.Geometry
    let key: Key
    let generator: @Sendable (D.Concrete) throws -> D.Concrete

    init(body: D.Geometry, key: Key, generator: @Sendable @escaping (D.Concrete) throws -> D.Concrete) {
        self.body = body
        self.key = key
        self.generator = generator
    }

    init(
        body: D.Geometry,
        name: String,
        parameters: any CacheKey...,
        generator: @Sendable @escaping (D.Concrete) throws -> D.Concrete
    ) where Key == LabeledCacheKey {
        self.init(
            body: body,
            key: LabeledCacheKey(operationName: name, parameters: parameters),
            generator: generator
        )
    }

    func _build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        let bodyResult = try await context.buildResult(for: body, in: environment)
        let bakedKey = NodeCacheKey(base: key, node: bodyResult.node)

        return try await context.materializedResult(buildResult: bodyResult, key: bakedKey) {
            let nodeResult = try await context.result(for: bodyResult.node)
            return try nodeResult.modified(generator)
        }
    }
}
