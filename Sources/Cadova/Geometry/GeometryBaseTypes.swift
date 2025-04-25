import Foundation

public struct Empty<D: Dimensionality>: Geometry {
    public init() {}
    
    public func build(in environment: EnvironmentValues, context: EvaluationContext) async -> D.Result {
        .init(.empty)
    }
}

struct ResultGeometry<D: Dimensionality>: Geometry {
    let result: D.Result

    func build(in environment: EnvironmentValues, context: EvaluationContext) async -> D.Result {
        result
    }
}

struct PrimitiveShape<D: Dimensionality>: Geometry {
    let shape: D.Expression.PrimitiveShape

    func build(in environment: EnvironmentValues, context: EvaluationContext) async -> D.Result {
        .init(.shape(shape))
    }
}

struct GeometryExpressionTransformer<Input: Dimensionality, D: Dimensionality>: Geometry {
    let body: Input.Geometry
    let expressionTransformer: @Sendable (Input.Expression) -> D.Expression
    let environmentTransformer: (@Sendable (EnvironmentValues) -> EnvironmentValues)?

    init(
        body: Input.Geometry,
        expressionTransformer: @Sendable @escaping (Input.Expression) -> D.Expression,
        environment environmentTransformer: (@Sendable (EnvironmentValues) -> EnvironmentValues)? = nil
    ) {
        self.body = body
        self.expressionTransformer = expressionTransformer
        self.environmentTransformer = environmentTransformer
    }

    func build(in environment: EnvironmentValues, context: EvaluationContext) async -> D.Result {
        let newEnvironment = environmentTransformer?(environment) ?? environment
        let bodyResult = await body.build(in: newEnvironment, context: context)
        return bodyResult.replacing(expression: expressionTransformer(bodyResult.expression))
    }
}

public protocol CompositeGeometry: Geometry {
    var body: D.Geometry { get }
}

extension CompositeGeometry {
    public func build(in environment: EnvironmentValues, context: EvaluationContext) async -> D.Result {
        await environment.whileCurrent {
            await body.build(in: environment, context: context)
        }
    }
}


struct BooleanGeometry<D: Dimensionality>: Geometry {
    let children: [D.Geometry]
    let type: BooleanOperationType

    func build(in environment: EnvironmentValues, context: EvaluationContext) async -> D.Result {
        let childResults = await children.asyncMap { await $0.build(in: environment, context: context) }
        return .init(combining: childResults, operationType: type)
    }
}

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

// Apply an arbitrary transformation to a body's primitive.

struct CachingPrimitiveTransformer<D: Dimensionality, Key: CacheKey>: Geometry {
    let body: D.Geometry
    let key: Key
    let generator: @Sendable (D.Primitive) -> D.Primitive

    func build(in environment: EnvironmentValues, context: EvaluationContext) async -> D.Result {
        let bodyResult = await body.build(in: environment, context: context)
        let bakedKey = GeometryCacheKey(base: key, expression: bodyResult.expression)

        if let cachedRawExpression: D.Expression = await context.cachedRawGeometry(key: bakedKey) {
            return bodyResult.replacing(expression: cachedRawExpression)

        } else {
            let bodyPrimitive = await context.geometry(for: bodyResult.expression)
            let expression = await context.storeRawGeometry(bodyPrimitive, key: bakedKey) as D.Expression
            return bodyResult.replacing(expression: expression)
        }
    }
}

internal struct GeometryCacheKey<Key: CacheKey, G: GeometryExpression>: CacheKey {
    let base: Key
    let expression: G
}

internal struct IndexedCacheKey<Key: CacheKey>: CacheKey {
    let base: Key
    let index: Int
}

struct CachingPrimitiveArrayTransformer<D: Dimensionality, Key: CacheKey>: Geometry {
    let body: D.Geometry
    let key: Key
    let generator: @Sendable (D.Primitive) -> [D.Primitive]
    let resultHandler: @Sendable ([D.Geometry]) -> D.Geometry

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

            geometries = parts.map { ResultGeometry(result: bodyResult.replacing(expression: $0)) as D.Geometry }

        } else {
            let bodyPrimitive = await context.geometry(for: bodyResult.expression)
            let primitives = generator(bodyPrimitive)

            geometries = await Array(primitives.enumerated()).asyncMap { index, primitive in
                let indexedKey = IndexedCacheKey(base: key, index: index)
                let expression: D.Expression = await context.storeRawGeometry(primitive, key: indexedKey)
                return ResultGeometry(result: bodyResult.replacing(expression: expression)) as D.Geometry
            }
        }

        return await resultHandler(geometries).build(in: environment, context: context)
    }
}
