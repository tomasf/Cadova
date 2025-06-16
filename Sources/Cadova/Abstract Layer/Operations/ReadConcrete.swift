import Foundation
import Manifold3D

internal struct ReadConcrete<Input: Dimensionality, Output: Dimensionality>: Geometry {
    let body: Input.Geometry
    let action: @Sendable (Input.Concrete, Input.BuildResult) -> Output.Geometry

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> Output.BuildResult {
        let bodyResult = try await context.buildResult(for: body, in: environment)
        let concreteResult = try await context.result(for: bodyResult.node)
        return try await context.buildResult(for: action(concreteResult.concrete, bodyResult), in: environment)
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
