import Foundation

internal struct GeometryCacheKey<Key: CacheKey, G: GeometryExpression>: CacheKey {
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

    func build(in environment: EnvironmentValues, context: EvaluationContext) async -> D.Result {
        if let cachedRawExpression: D.Expression = await context.cachedRawGeometry(key: key) {
            let resultElements = await context.resultElements(for: key) ?? [:]
            return D.Result(expression: cachedRawExpression, elements: resultElements)
        } else {
            let results = await generator().build(in: environment, context: context)
            let primitive = await context.geometry(for: results.expression)
            await context.setResultElements(results.elements, for: key)

            return await D.Result(
                expression: context.storeRawGeometry(primitive, key: key),
                elements: results.elements
            )
        }
    }
}

// Caches a leaf primitive

struct CachingPrimitive<D: Dimensionality, Key: CacheKey>: Geometry {
    let key: Key
    let generator: @Sendable () -> D.Primitive

    func build(in environment: EnvironmentValues, context: EvaluationContext) async -> D.Result {
        if let cachedRawExpression: D.Expression = await context.cachedRawGeometry(key: key) {
            return D.Result(cachedRawExpression)
        } else {
            return await D.Result(context.storeRawGeometry(generator(), key: key))
        }
    }
}

// Apply an arbitrary transformation to a body's primitive, cached based on expression + key

struct CachingPrimitiveTransformer<D: Dimensionality, Key: CacheKey>: Geometry {
    let body: D.Geometry
    let key: Key
    let generator: @Sendable (D.Primitive) -> D.Primitive

    init(body: D.Geometry, key: Key, generator: @Sendable @escaping (D.Primitive) -> D.Primitive) {
        self.body = body
        self.key = key
        self.generator = generator
    }

    init(body: D.Geometry, name: String, parameters: any CacheKey..., generator: @Sendable @escaping (D.Primitive) -> D.Primitive) where Key == NamedCacheKey {
        self.init(
            body: body,
            key: NamedCacheKey(operationName: name, parameters: parameters),
            generator: generator
        )
    }

    func build(in environment: EnvironmentValues, context: EvaluationContext) async -> D.Result {
        let bodyResult = await body.build(in: environment, context: context)
        let bakedKey = GeometryCacheKey(base: key, expression: bodyResult.expression)

        if let cachedRawExpression: D.Expression = await context.cachedRawGeometry(key: bakedKey) {
            return bodyResult.replacing(expression: cachedRawExpression)

        } else {
            let bodyPrimitive = await context.geometry(for: bodyResult.expression)
            let expression = await context.storeRawGeometry(generator(bodyPrimitive), key: bakedKey) as D.Expression
            return bodyResult.replacing(expression: expression)
        }
    }
}

// Apply an arbitrary transformation to a body's primitive, returning a variable number
// of resulting primitives, individually cached based on expression + key + index

struct CachingPrimitiveArrayTransformer<D: Dimensionality, Key: CacheKey>: Geometry {
    let body: D.Geometry
    let key: Key
    let generator: @Sendable (D.Primitive) -> [D.Primitive]
    let resultHandler: @Sendable ([D.Geometry]) -> D.Geometry

    init(
        body: D.Geometry,
        key: Key, generator: @Sendable @escaping (D.Primitive) -> [D.Primitive],
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
        generator: @Sendable @escaping (D.Primitive) -> [D.Primitive],
        resultHandler: @Sendable @escaping ([D.Geometry]) -> D.Geometry
    ) where Key == NamedCacheKey {
        self.init(
            body: body,
            key: NamedCacheKey(operationName: name, parameters: parameters),
            generator: generator,
            resultHandler: resultHandler
        )
    }

    func build(in environment: EnvironmentValues, context: EvaluationContext) async -> D.Result {
        let bodyResult = await body.build(in: environment, context: context)

        let bakedKey = GeometryCacheKey(base: key, expression: bodyResult.expression)
        let firstKey = IndexedCacheKey(base: bakedKey, index: 0)
        let firstPart = await context.cachedRawGeometry(key: firstKey) as D.Expression?
        let geometries: [D.Geometry]

        if let firstPart {
            var parts: [D.Expression] = [firstPart]
            for i in 1... {
                let indexedKey = IndexedCacheKey(base: bakedKey, index: i)
                guard let part: D.Expression = await context.cachedRawGeometry(key: indexedKey) else {
                    break
                }
                parts.append(part)
            }

            geometries = parts.map { bodyResult.replacing(expression: $0) }

        } else {
            let bodyPrimitive = await context.geometry(for: bodyResult.expression)
            let primitives = generator(bodyPrimitive)

            geometries = await Array(primitives.enumerated()).asyncMap { index, primitive in
                let indexedKey = IndexedCacheKey(base: key, index: index)
                let expression: D.Expression = await context.storeRawGeometry(primitive, key: indexedKey)
                return bodyResult.replacing(expression: expression)
            }
        }

        return await resultHandler(geometries).build(in: environment, context: context)
    }
}
