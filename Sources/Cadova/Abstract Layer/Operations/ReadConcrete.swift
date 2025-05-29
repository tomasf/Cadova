import Foundation
import Manifold3D

internal struct ReadConcrete<Input: Dimensionality, Output: Dimensionality>: Geometry {
    let body: Input.Geometry
    let action: @Sendable (Input.Concrete, Input.BuildResult) -> Output.Geometry

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> Output.BuildResult {
        let bodyResult = try await body.build(in: environment, context: context)
        let nodeResult = await context.result(for: bodyResult.node)
        return try await action(nodeResult.concrete, bodyResult).build(in: environment, context: context)
    }
}

internal extension Geometry {
    // Concrete + Result
    func readingConcrete<Output: Dimensionality>(
        _ action: @Sendable @escaping (D.Concrete, D.BuildResult) -> Output.Geometry
    ) -> Output.Geometry {
        ReadConcrete(body: self, action: action)
    }

    // Concrete only
    func readingConcrete<Output: Dimensionality>(
        _ action: @Sendable @escaping (D.Concrete) -> Output.Geometry
    ) -> Output.Geometry {
        readingConcrete { concrete, _ in
            action(concrete)
        }
    }
}
