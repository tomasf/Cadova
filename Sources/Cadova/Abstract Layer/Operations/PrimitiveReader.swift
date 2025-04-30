import Foundation
import Manifold3D

internal struct ReadPrimitive<Input: Dimensionality, Output: Dimensionality>: Geometry {
    let body: Input.Geometry
    let action: @Sendable (Input.Concrete, Input.BuildResult) -> Output.Geometry

    func build(in environment: EnvironmentValues, context: EvaluationContext) async -> Output.BuildResult {
        let bodyResult = await body.build(in: environment, context: context)
        let nodeResult = await context.result(for: bodyResult.node)
        return await action(nodeResult.concrete, bodyResult).build(in: environment, context: context)
    }
}

internal extension Geometry {
    // Primtive + Result
    func readingPrimitive<Output: Dimensionality>(
        _ action: @Sendable @escaping (D.Concrete, D.BuildResult) -> Output.Geometry
    ) -> Output.Geometry {
        ReadPrimitive(body: self, action: action)
    }

    // Primitive only
    func readingPrimitive<Output: Dimensionality>(
        _ action: @Sendable @escaping (D.Concrete) -> Output.Geometry
    ) -> Output.Geometry {
        readingPrimitive { primitive, _ in
            action(primitive)
        }
    }
}
