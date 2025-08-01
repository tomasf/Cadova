import Foundation

// Caches a leaf concrete

struct CachedConcrete<D: Dimensionality, Key: CacheKey>: Geometry {
    let key: Key
    let generator: @Sendable () async throws -> D.Concrete

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        if try await context.hasCachedResult(for: key, with: D.self) {
            D.BuildResult(cacheKey: key, elements: [:])
        } else {
            try await D.BuildResult(context.storeMaterializedResult(D.Node.Result(generator()), key: key))
        }
    }

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

        if try await context.hasCachedResult(for: bakedKey, with: D.self) {
            return bodyResult.replacing(cacheKey: bakedKey)

        } else {
            let nodeResult = try await context.result(for: bodyResult.node)
            let newResult = try nodeResult.modified(generator)

            let node = await context.storeMaterializedResult(newResult, key: bakedKey) as D.Node
            return bodyResult.replacing(node: node)
        }
    }
}

// Apply an arbitrary transformation to a body's concrete, returning a variable number
// of resulting concretes, individually cached based on node + key + index

struct CachedConcreteArrayTransformer<D: Dimensionality, Key: CacheKey>: Geometry {
    let body: D.Geometry
    let key: Key
    let generator: @Sendable (D.Concrete) throws -> [D.Concrete]
    let resultHandler: @Sendable ([D.Geometry]) -> D.Geometry

    init(
        body: D.Geometry,
        key: Key, generator: @Sendable @escaping (D.Concrete) throws -> [D.Concrete],
        resultHandler: @Sendable @escaping ([D.Geometry]) -> D.Geometry
    ) {
        self.body = body
        self.key = key
        self.generator = generator
        self.resultHandler = resultHandler
    }

    init(
        body: D.Geometry,
        name: String,
        parameters: any CacheKey...,
        generator: @Sendable @escaping (D.Concrete) throws -> [D.Concrete],
        resultHandler: @Sendable @escaping ([D.Geometry]) -> D.Geometry
    ) where Key == LabeledCacheKey {
        self.init(
            body: body,
            key: LabeledCacheKey(operationName: name, parameters: parameters),
            generator: generator,
            resultHandler: resultHandler
        )
    }

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        let bodyResult = try await context.buildResult(for: body, in: environment)

        let bakedKey = NodeCacheKey(base: key, node: bodyResult.node)
        let firstKey = IndexedCacheKey(base: bakedKey, index: 0)
        let geometries: [D.Geometry]

        if try await context.hasCachedResult(for: firstKey, with: D.self) {
            var parts: [IndexedCacheKey] = [firstKey]
            for i in 1... {
                let indexedKey = IndexedCacheKey(base: bakedKey, index: i)

                guard try await context.hasCachedResult(for: indexedKey, with: D.self) else {
                    break
                }
                parts.append(indexedKey)
            }

            geometries = parts.map { bodyResult.replacing(cacheKey: $0) }

        } else {
            let nodeResult = try await context.result(for: bodyResult.node)
            let concretes = try generator(nodeResult.concrete)

            geometries = try await Array(concretes.enumerated()).asyncMap { index, concrete in
                let indexedKey = IndexedCacheKey(base: bakedKey, index: index)
                let node: D.Node = try await context.storeMaterializedResult(nodeResult.modified { _ in concrete }, key: indexedKey)
                return bodyResult.replacing(node: node)
            }
        }

        return try await context.buildResult(for: resultHandler(geometries), in: environment)
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

        if try await context.hasCachedResult(for: bakedKey, with: D.self) {
            return bodyResult.replacing(cacheKey: bakedKey)

        } else {
            let outputNode = try await generator(bodyResult.node, environment, context)
            let nodeResult = try await context.result(for: outputNode)

            let node = await context.storeMaterializedResult(nodeResult, key: bakedKey) as D.Node
            return bodyResult.replacing(node: node)
        }
    }
}

struct CachedNode<D: Dimensionality>: Geometry {
    let key: LabeledCacheKey
    let generator: @Sendable (EnvironmentValues, EvaluationContext) async throws -> D.Node

    init(
        name: String,
        parameters: any CacheKey...,
        generator: @Sendable @escaping (EnvironmentValues, EvaluationContext) async throws -> D.Node)
    {
        self.key = LabeledCacheKey(operationName: name, parameters: parameters)
        self.generator = generator
    }

    // Cached node built from abstract geometry. Use this as a convenience and keep in mind result elements are discarded.
    init(
        name: String,
        parameters: any CacheKey...,
        generator: @Sendable @escaping () async throws -> D.Geometry)
    {
        self.key = LabeledCacheKey(operationName: name, parameters: parameters)
        self.generator = { environment, context in
            try await context.buildResult(for: generator(), in: environment).node
        }
    }

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        if try await context.hasCachedResult(for: key, with: D.self) {
            return D.BuildResult(.materialized(cacheKey: OpaqueKey(key)))

        } else {
            let outputNode = try await generator(environment, context)
            let nodeResult = try await context.result(for: outputNode)

            let node = await context.storeMaterializedResult(nodeResult, key: key) as D.Node
            return D.BuildResult(node)
        }
    }
}
