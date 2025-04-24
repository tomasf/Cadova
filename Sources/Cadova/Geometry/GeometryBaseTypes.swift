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

struct CachingPrimitive<D: Dimensionality, Key: CacheKey>: Geometry {
    let key: Key
    let primitive: D.Primitive

    func build(in environment: EnvironmentValues, context: EvaluationContext) async -> D.Result {
        if let cachedRawExpression: D.Expression = await context.cachedRawGeometry(for: nil, key: key) {
            return D.Result(cachedRawExpression)
        } else {
            return D.Result(.raw(primitive, source: nil, cacheKey: OpaqueKey(key)))
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

        if let cachedRawExpression = await context.cachedRawGeometry(for: bodyResult.expression, key: key) {
            return bodyResult.replacing(expression: cachedRawExpression)

        } else {
            let bodyPrimitive = await context.geometry(for: bodyResult.expression)
            let expression = await context.storeRawGeometry(bodyPrimitive, for: bodyResult.expression, key: key)
            return bodyResult.replacing(expression: expression)
        }
    }
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

        let firstKey = IndexedCacheKey(base: key, index: 0)
        let firstPart = await context.cachedRawGeometry(for: bodyResult.expression, key: firstKey)
        let geometries: [D.Geometry]

        if let firstPart {
            var parts: [D.Expression] = [firstPart]
            for i in 1... {
                let indexedKey = IndexedCacheKey(base: key, index: i)
                guard let part = await context.cachedRawGeometry(for: bodyResult.expression, key: indexedKey) else {
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
                let expression = await context.storeRawGeometry(primitive, for: bodyResult.expression, key: indexedKey)
                return ResultGeometry(result: bodyResult.replacing(expression: expression)) as D.Geometry
            }
        }

        return await resultHandler(geometries).build(in: environment, context: context)
    }
}
