import Foundation

internal struct NodeCacheKey<Key: CacheKey, D: Dimensionality>: CacheKey {
    let base: Key
    let node: D.Node
}

internal struct IndexedCacheKey<Key: CacheKey>: CacheKey {
    let base: Key
    let index: Int
}

// Boxes a geometry tree behind a freestanding cache key, avoiding both node building
// and primitive generation

struct CachedBoxedGeometry<D: Dimensionality, Key: CacheKey, ID: Dimensionality>: Geometry {
    let key: Key
    let geometry: (any Geometry<ID>)?
    let generator: @Sendable () -> D.Geometry

    init(key: Key, geometry: ID.Geometry?, generator: @Sendable @escaping () -> D.Geometry) {
        self.key = key
        self.geometry = geometry
        self.generator = generator
    }

    init(operationName: String, parameters: any Hashable & Sendable & Codable..., generator: @Sendable @escaping () -> D.Geometry) where Key == NamedCacheKey, ID == D3 {
        self.init(key: NamedCacheKey(operationName: operationName, parameters: parameters), geometry: nil, generator: generator)
    }

    func build(in environment: EnvironmentValues, context: EvaluationContext) async -> D.BuildResult {
        let bakedKey: any CacheKey
        if let geometry {
            let node = await geometry.build(in: environment, context: context).node
            bakedKey = NodeCacheKey(base: key, node: node)
        } else {
            bakedKey = key
        }

        if await context.hasCachedResult(for: bakedKey, with: D.self) {
            let resultElements = await context.resultElements(for: bakedKey) ?? [:]
            return D.BuildResult(cacheKey: bakedKey, elements: resultElements)
        } else {
            let results = await generator().build(in: environment, context: context)
            let nodeResults = await context.result(for: results.node)
            await context.setResultElements(results.elements, for: bakedKey)
            return await results.replacing(node: context.storeMaterializedResult(nodeResults, key: bakedKey))
        }
    }
}

// Caches a leaf primitive

struct CachingPrimitive<D: Dimensionality, Key: CacheKey>: Geometry {
    let key: Key
    let generator: @Sendable () async -> D.Concrete

    func build(in environment: EnvironmentValues, context: EvaluationContext) async -> D.BuildResult {
        if await context.hasCachedResult(for: key, with: D.self) {
            D.BuildResult(cacheKey: key, elements: [:])
        } else {
            await D.BuildResult(context.storeMaterializedResult(D.Node.Result(generator()), key: key))
        }
    }

    init(key: Key, generator: @Sendable @escaping () async -> D.Concrete) {
        self.key = key
        self.generator = generator
    }

    init(name: String, parameters: any CacheKey..., generator: @Sendable @escaping () async -> D.Concrete) where Key == NamedCacheKey {
        self.init(key: NamedCacheKey(operationName: name, parameters: parameters), generator: generator)
    }
}

// Apply an arbitrary transformation to a body's primitive, cached based on node + key

struct CachingPrimitiveTransformer<D: Dimensionality, Key: CacheKey>: Geometry {
    let body: D.Geometry
    let key: Key
    let generator: @Sendable (D.Concrete) -> D.Concrete

    init(body: D.Geometry, key: Key, generator: @Sendable @escaping (D.Concrete) -> D.Concrete) {
        self.body = body
        self.key = key
        self.generator = generator
    }

    init(body: D.Geometry, name: String, parameters: any CacheKey..., generator: @Sendable @escaping (D.Concrete) -> D.Concrete) where Key == NamedCacheKey {
        self.init(
            body: body,
            key: NamedCacheKey(operationName: name, parameters: parameters),
            generator: generator
        )
    }

    func build(in environment: EnvironmentValues, context: EvaluationContext) async -> D.BuildResult {
        let bodyResult = await body.build(in: environment, context: context)
        let bakedKey = NodeCacheKey(base: key, node: bodyResult.node)

        if await context.hasCachedResult(for: bakedKey, with: D.self) {
            return bodyResult.replacing(cacheKey: bakedKey)

        } else {
            let nodeResult = await context.result(for: bodyResult.node)
            let newResult = nodeResult.modified(generator)

            let node = await context.storeMaterializedResult(newResult, key: bakedKey) as D.Node
            return bodyResult.replacing(node: node)
        }
    }
}

// Apply an arbitrary transformation to a body's primitive, returning a variable number
// of resulting primitives, individually cached based on node + key + index

struct CachingPrimitiveArrayTransformer<D: Dimensionality, Key: CacheKey>: Geometry {
    let body: D.Geometry
    let key: Key
    let generator: @Sendable (D.Concrete) -> [D.Concrete]
    let resultHandler: @Sendable ([D.Geometry]) -> D.Geometry

    init(
        body: D.Geometry,
        key: Key, generator: @Sendable @escaping (D.Concrete) -> [D.Concrete],
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
        generator: @Sendable @escaping (D.Concrete) -> [D.Concrete],
        resultHandler: @Sendable @escaping ([D.Geometry]) -> D.Geometry
    ) where Key == NamedCacheKey {
        self.init(
            body: body,
            key: NamedCacheKey(operationName: name, parameters: parameters),
            generator: generator,
            resultHandler: resultHandler
        )
    }

    func build(in environment: EnvironmentValues, context: EvaluationContext) async -> D.BuildResult {
        let bodyResult = await body.build(in: environment, context: context)

        let bakedKey = NodeCacheKey(base: key, node: bodyResult.node)
        let firstKey = IndexedCacheKey(base: bakedKey, index: 0)
        let geometries: [D.Geometry]

        if await context.hasCachedResult(for: firstKey, with: D.self) {
            var parts: [IndexedCacheKey] = [firstKey]
            for i in 1... {
                let indexedKey = IndexedCacheKey(base: bakedKey, index: i)

                guard await context.hasCachedResult(for: indexedKey, with: D.self) else {
                    break
                }
                parts.append(indexedKey)
            }

            geometries = parts.map { bodyResult.replacing(cacheKey: $0) }

        } else {
            let nodeResult = await context.result(for: bodyResult.node)
            let primitives = generator(nodeResult.concrete)

            geometries = await Array(primitives.enumerated()).asyncMap { index, primitive in
                let indexedKey = IndexedCacheKey(base: key, index: index)
                let node: D.Node = await context.storeMaterializedResult(nodeResult.modified { _ in primitive }, key: indexedKey)
                return bodyResult.replacing(node: node)
            }
        }

        return await resultHandler(geometries).build(in: environment, context: context)
    }
}

// Apply an arbitrary transformation to a node, cached based on node + key

struct CachingTransformer<D: Dimensionality, Input: Dimensionality>: Geometry {
    let body: Input.Geometry
    let key: NamedCacheKey
    let generator: @Sendable (Input.Node, EnvironmentValues, EvaluationContext) async -> D.Node

    init(body: Input.Geometry, name: String, parameters: any CacheKey..., generator: @Sendable @escaping (Input.Node, EnvironmentValues, EvaluationContext) async -> D.Node) {
        self.body = body
        self.key = NamedCacheKey(operationName: name, parameters: parameters)
        self.generator = generator
    }

    func build(in environment: EnvironmentValues, context: EvaluationContext) async -> D.BuildResult {
        let bodyResult = await body.build(in: environment, context: context)
        let bakedKey = NodeCacheKey(base: key, node: bodyResult.node)

        if await context.hasCachedResult(for: bakedKey, with: D.self) {
            return bodyResult.replacing(cacheKey: bakedKey)

        } else {
            let outputNode = await generator(bodyResult.node, environment, context)
            let nodeResult = await context.result(for: outputNode)

            let node = await context.storeMaterializedResult(nodeResult, key: bakedKey) as D.Node
            return bodyResult.replacing(node: node)
        }
    }
}
