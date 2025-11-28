import Foundation

// Caches a leaf concrete

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

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        try await context.materializedResult(key: key) {
            try await D.Node.Result(generator())
        }
    }
}

// Apply an arbitrary transformation to a body's concrete, cached based on node + key

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

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        let bodyResult = try await context.buildResult(for: body, in: environment)
        let bakedKey = NodeCacheKey(base: key, node: bodyResult.node)

        return try await context.materializedResult(buildResult: bodyResult, key: bakedKey) {
            let nodeResult = try await context.result(for: bodyResult.node)
            return try nodeResult.modified(generator)
        }
    }
}

// Apply an arbitrary transformation to a node, cached based on node + key

struct CachedNodeTransformer<D: Dimensionality, Input: Dimensionality>: Geometry {
    let body: Input.Geometry
    let key: LabeledCacheKey
    let generator: @Sendable (Input.Node, EnvironmentValues, EvaluationContext) async throws -> D.Node

    init(
        body: Input.Geometry,
        name: String,
        parameters: any CacheKey...,
        generator: @Sendable @escaping (Input.Node, EnvironmentValues, EvaluationContext) async throws -> D.Node
    ) {
        self.body = body
        self.key = LabeledCacheKey(operationName: name, parameters: parameters)
        self.generator = generator
    }

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        let bodyResult = try await context.buildResult(for: body, in: environment)
        let bakedKey = NodeCacheKey(base: key, node: bodyResult.node)

        return try await context.materializedResult(buildResult: bodyResult, key: bakedKey) {
            let outputNode = try await generator(bodyResult.node, environment, context)
            return try await context.result(for: outputNode)
        }
    }
}

struct CachedNode<D: Dimensionality>: Geometry {
    let key: LabeledCacheKey
    let generator: @Sendable (EnvironmentValues, EvaluationContext) async throws -> D.Node

    init(
        name: String,
        parameters: any CacheKey...,
        generator: @Sendable @escaping (EnvironmentValues, EvaluationContext) async throws -> D.Node
    ){
        self.key = LabeledCacheKey(operationName: name, parameters: parameters)
        self.generator = generator
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

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        try await context.materializedResult(key: key) {
            let outputNode = try await generator(environment, context)
            return try await context.result(for: outputNode)
        }
    }
}
