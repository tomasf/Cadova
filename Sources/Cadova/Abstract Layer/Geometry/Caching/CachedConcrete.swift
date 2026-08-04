import Foundation

/// Builds and caches a leaf concrete result produced by a generator closure, with no input geometry
/// of its own. The generator runs at most once per distinct `key`; later builds that share a key
/// reuse the cached concrete instead of calling the generator again.
struct CachedConcrete<D: Dimensionality, Key: CacheKey>: Geometry {
    let key: Key
    let generator: @Sendable () async throws -> D.Concrete

    init(key: Key, generator: @Sendable @escaping () async throws -> D.Concrete) {
        self.key = key
        self.generator = generator
    }

    init(
        name: String,
        parameters: any CacheKey...,
        generator: @Sendable @escaping () async throws -> D.Concrete
    ) where Key == LabeledCacheKey {
        self.init(key: LabeledCacheKey(operationName: name, parameters: parameters), generator: generator)
    }

    func _build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> BuildResult<D> {
        try await context.materializedResult(key: key) {
            try await D.Node.Result(generator())
        }
    }
}
