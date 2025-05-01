import Foundation

internal struct GeometryCacheKey<Key: CacheKey, G: GeometryNode>: CacheKey {
    let base: Key
    let expression: G
}

internal struct IndexedCacheKey<Key: CacheKey>: CacheKey {
    let base: Key
    let index: Int
}

// Boxes a geometry tree behind a freestanding cache key, avoiding both expression building
// and primitive generation

struct CachedBoxedGeometry<D: Dimensionality, Key: CacheKey>: Geometry {
    let key: Key
    let generator: @Sendable () -> D.Geometry

    func build(in environment: EnvironmentValues, context: EvaluationContext) async -> D.BuildResult {
        if await context.hasCachedResult(for: key, with: D.self) {
            let resultElements = await context.resultElements(for: key) ?? [:]
            return D.BuildResult(cacheKey: key, elements: resultElements)
        } else {
            let results = await generator().build(in: environment, context: context)
            let nodeResults = await context.result(for: results.node)
            await context.setResultElements(results.elements, for: key)
            return await results.replacing(node: context.storeMaterializedResult(nodeResults, key: key))
        }
    }
}

// Caches a leaf primitive

struct CachingPrimitive<D: Dimensionality, Key: CacheKey>: Geometry {
    let key: Key
    let generator: @Sendable () -> D.Concrete

    func build(in environment: EnvironmentValues, context: EvaluationContext) async -> D.BuildResult {
        if await context.hasCachedResult(for: key, with: D.self) {
            D.BuildResult(cacheKey: key, elements: [:])
        } else {
            await D.BuildResult(context.storeMaterializedResult(D.Node.Result(generator()), key: key))
        }
    }
}

// Apply an arbitrary transformation to a body's primitive, cached based on expression + key

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
        let bakedKey = GeometryCacheKey(base: key, expression: bodyResult.node)

        if await context.hasCachedResult(for: bakedKey, with: D.self) {
            return bodyResult.replacing(cacheKey: bakedKey)

        } else {
            let nodeResult = await context.result(for: bodyResult.node)
            let newResult = nodeResult.modified(generator)

            let expression = await context.storeMaterializedResult(newResult, key: bakedKey) as D.Node
            return bodyResult.replacing(node: expression)
        }
    }
}

// Apply an arbitrary transformation to a body's primitive, returning a variable number
// of resulting primitives, individually cached based on expression + key + index

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

        let bakedKey = GeometryCacheKey(base: key, expression: bodyResult.node)
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
                let expression: D.Node = await context.storeMaterializedResult(nodeResult.modified { _ in primitive }, key: indexedKey)
                return bodyResult.replacing(node: expression)
            }
        }

        return await resultHandler(geometries).build(in: environment, context: context)
    }
}
