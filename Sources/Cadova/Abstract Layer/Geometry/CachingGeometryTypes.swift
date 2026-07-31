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

    func _build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        try await context.materializedResult(key: key) {
            try await D.Node.Result(generator())
        }
    }
}

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

    func _build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        let bodyResult = try await context.buildResult(for: source, in: environment)
        let bakedKey = NodeCacheKey(base: key, node: bodyResult.node)

        return try await context.materializedResult(buildResult: bodyResult, key: bakedKey) {
            let outputNode = try await generator(bodyResult.node, environment, context)
            return try await context.result(for: outputNode)
        }
    }
}

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

    func _build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        try await context.materializedResult(key: key) {
            let outputNode = try await generator(environment, context)
            return try await context.result(for: outputNode)
        }
    }
}
