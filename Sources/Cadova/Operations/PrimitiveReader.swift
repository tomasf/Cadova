import Foundation
import Manifold3D

internal struct ReadPrimitive<Input: Dimensionality, Output: Dimensionality>: Geometry {
    let body: Input.Geometry
    let action: @Sendable (Input.Primitive, Input.Result) -> Output.Geometry

    func build(in environment: EnvironmentValues, context: EvaluationContext) async -> Output.Result {
        let bodyResult = await body.build(in: environment, context: context)
        let expressionResult = await context.geometry(for: bodyResult.expression)
        return await action(expressionResult.primitive, bodyResult).build(in: environment, context: context)
    }
}

internal extension Geometry {
    // Primtive + Result
    func readingPrimitive<Output: Dimensionality>(
        _ action: @Sendable @escaping (D.Primitive, D.Result) -> Output.Geometry
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
