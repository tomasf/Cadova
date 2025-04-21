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
            return bodyResult.replacing(
                expression: .raw(generator(bodyPrimitive), source: bodyResult.expression, cacheKey: OpaqueKey(key))
            )
        }
    }
}

struct CachingPrimitiveArrayTransformer<D: Dimensionality, Key: CacheKey>: Geometry {
    let body: D.Geometry
    let keys: [Key]
    let generator: @Sendable (D.Primitive) -> [D.Primitive]
    let resultHandler: @Sendable ([D.Geometry]) -> D.Geometry

    private struct CacheKey: Cadova.CacheKey {
        let body: D.Expression
        let parameters: Key
    }

    func build(in environment: EnvironmentValues, context: EvaluationContext) async -> D.Result {
        let bodyResult = await body.build(in: environment, context: context)
        let combinedKeys = keys.map { CacheKey(body: bodyResult.expression, parameters: $0) }

        let cachedRawExpressions = await combinedKeys.asyncMap { cacheKey in
            await context.cachedRawGeometry(for: bodyResult.expression, key: cacheKey) as D.Expression?
        }.compactMap { $0 }
        let wasFoundInCache = (cachedRawExpressions.count == combinedKeys.count)

        if wasFoundInCache {
            let geometries = cachedRawExpressions.map {
                ResultGeometry(result: bodyResult.replacing(expression: $0)) as D.Geometry
            }

            return await resultHandler(geometries).build(in: environment, context: context)
        } else {
            if cachedRawExpressions.count > 0 {
                logger.warning("CachingPrimitiveArrayTransformer found *some* cached pieces, but not all.")
            }

            let bodyPrimitive = await context.geometry(for: bodyResult.expression)
            let primitives = generator(bodyPrimitive)
            precondition(primitives.count == combinedKeys.count, "Generated primitive count must match key count")

            let geometries = zip(primitives, combinedKeys).map { primitive, cacheKey in
                let expression = D.Expression.raw(primitive, source: bodyResult.expression, cacheKey: .init(cacheKey))
                return ResultGeometry(result: bodyResult.replacing(expression: expression)) as D.Geometry
            }

            return await resultHandler(geometries).build(in: environment, context: context)
        }
    }
}
