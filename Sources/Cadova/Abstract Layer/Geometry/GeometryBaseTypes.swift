import Foundation

public struct Empty<D: Dimensionality>: Geometry {
    public init() {}
    
    public func build(in environment: EnvironmentValues, context: EvaluationContext) async -> D.BuildResult {
        .init(.empty)
    }
}

struct PrimitiveShape<D: Dimensionality>: Geometry {
    let shape: D.Node.PrimitiveShape

    func build(in environment: EnvironmentValues, context: EvaluationContext) async -> D.BuildResult {
        .init(.shape(shape))
    }
}

struct GeometryNodeTransformer<Input: Dimensionality, D: Dimensionality>: Geometry {
    let transformer: @Sendable (EnvironmentValues, EvaluationContext) async -> D.BuildResult

    init(
        body: Input.Geometry,
        expressionTransformer: @Sendable @escaping (Input.Node) -> D.Node,
        environment environmentTransformer: (@Sendable (EnvironmentValues) -> EnvironmentValues)? = nil
    ) {
        transformer = { environment, context in
            let newEnvironment = environmentTransformer?(environment) ?? environment
            let bodyResult = await body.build(in: newEnvironment, context: context)
            return bodyResult.replacing(expression: expressionTransformer(bodyResult.node))
        }
    }

    init(
        bodies: [Input.Geometry],
        expressionTransformer: @Sendable @escaping ([Input.Node]) -> D.Node
    ) {
        transformer = { environment, context in
            let results = await bodies.asyncMap { await $0.build(in: environment, context: context) }
            let expression = expressionTransformer(results.map(\.node))
            return .init(node: expression, elements: .init(combining: results.map(\.elements)))
        }
    }

    func build(in environment: EnvironmentValues, context: EvaluationContext) async -> D.BuildResult {
        await transformer(environment, context)
    }
}

// Dimensionality-independent Shape equivalent

public protocol CompositeGeometry: Geometry {
    var body: D.Geometry { get }
}

extension CompositeGeometry {
    public func build(in environment: EnvironmentValues, context: EvaluationContext) async -> D.BuildResult {
        await environment.whileCurrent {
            await body.build(in: environment, context: context)
        }
    }
}


struct BooleanGeometry<D: Dimensionality>: Geometry {
    let children: [D.Geometry]
    let type: BooleanOperationType

    func build(in environment: EnvironmentValues, context: EvaluationContext) async -> D.BuildResult {
        let childResults = await children.asyncMap { await $0.build(in: environment, context: context) }
        return .init(combining: childResults, operationType: type)
    }
}
