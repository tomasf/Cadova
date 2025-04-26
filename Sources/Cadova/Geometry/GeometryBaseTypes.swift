import Foundation

public struct Empty<D: Dimensionality>: Geometry {
    public init() {}
    
    public func build(in environment: EnvironmentValues, context: EvaluationContext) async -> D.Result {
        .init(.empty)
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

// Dimensionality-independent Shape equivalent

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
