import Foundation

/// Produces and caches a node from a generator closure, keyed by name and parameters rather than
/// by any input geometry — the closure is expected to be pure with respect to its key, since a
/// second build with the same key skips the closure entirely and reuses the cached node.
struct CachedNode<D: Dimensionality>: Geometry {
    let key: LabeledCacheKey
    let generator: @Sendable (EnvironmentValues, EvaluationContext) async throws -> D.Node

    init(
        name: String,
        parameters: any CacheKey...,
        generator: @Sendable @escaping (EvaluationContext) async throws -> D.Node
    ){
        self.key = LabeledCacheKey(operationName: name, parameters: parameters)
        self.generator = { try await generator($1) }
    }

    // Cached node built from abstract geometry. Use this as a convenience and keep in mind result elements are discarded.
    init(
        labeledCacheKey: LabeledCacheKey,
        generator: @Sendable @escaping () async throws -> D.Geometry
    ){
        self.key = labeledCacheKey
        self.generator = { environment, context in
            try await context.buildResult(for: generator(), in: environment).node
        }
    }

    init(
        name: String,
        parameters: any CacheKey...,
        generator: @Sendable @escaping () async throws -> D.Geometry
    ){
        self.init(
            labeledCacheKey: LabeledCacheKey(operationName: name, parameters: parameters),
            generator: generator
        )
    }

    func _build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> BuildResult<D> {
        try await context.materializedResult(key: key) {
            let outputNode = try await generator(environment, context)
            return try await context.result(for: outputNode)
        }
    }
}
