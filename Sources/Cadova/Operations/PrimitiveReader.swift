import Foundation
import Manifold3D

internal struct ReadExpression<Input: Dimensionality, Output: Dimensionality>: Geometry {
    let body: Input.Geometry
    let action: @Sendable (Input.Expression) -> Output.Geometry

    func build(in environment: EnvironmentValues, context: EvaluationContext) async -> Output.Result {
        let bodyResult = await body.build(in: environment, context: context)
        return await action(bodyResult.expression).build(in: environment, context: context)
    }
}

internal extension Geometry {
    func readingExpression<Output: Dimensionality>(
        _ action: @Sendable @escaping (D.Expression) -> Output.Geometry
    ) -> Output.Geometry {
        ReadExpression(body: self, action: action)
    }
}

internal struct ReadPrimitive<Input: Dimensionality, Output: Dimensionality>: Geometry {
    let body: Input.Geometry
    let action: @Sendable (Input.Primitive, Input.Expression) -> Output.Geometry

    func build(in environment: EnvironmentValues, context: EvaluationContext) async -> Output.Result {
        let bodyResult = await body.build(in: environment, context: context)
        let primitive = await context.geometry(for: bodyResult.expression)
        return await action(primitive, bodyResult.expression).build(in: environment, context: context)
    }
}

internal extension Geometry {
    // Primtive + Expression
    func readingPrimitive<Output: Dimensionality>(
        _ action: @Sendable @escaping (D.Primitive, D.Expression) -> Output.Geometry
    ) -> Output.Geometry {
        ReadPrimitive(body: self, action: action)
    }

    // Primitive only
    func readingPrimitive<Output: Dimensionality>(
        _ action: @Sendable @escaping (D.Primitive) -> Output.Geometry
    ) -> Output.Geometry {
        readingPrimitive { primitive, _ in
            action(primitive)
        }
    }
}
