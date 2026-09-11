import Foundation
import Manifold3D

internal struct ReadConcrete<Input: Dimensionality, Output: Dimensionality>: Geometry {
    let source: Input.Geometry
    // The action's second argument is a stand-in for `source` that replays the build performed here,
    // so returning geometry derived from it doesn't walk the source subtree a second time.
    let action: @Sendable (Input.Concrete, Input.Geometry) -> Output.Geometry

    func _build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> BuildResult<Output> {
        let bodyResult = try await context.buildResult(for: source, in: environment)
        let concreteResult = try await context.result(for: bodyResult.node)
        let standIn = bodyResult.standingIn(for: source, in: environment, context: context)
        return try await context.buildResult(for: action(concreteResult.concrete, standIn), in: environment)
    }
}

internal extension Geometry {
    // Concrete + the source geometry, pre-built
    func readingConcrete<Output: Dimensionality>(
        @GeometryBuilder<Output> _ action: @Sendable @escaping (D.Concrete, D.Geometry) -> Output.Geometry
    ) -> Output.Geometry {
        ReadConcrete(source: self, action: action)
    }

    // Concrete only
    func readingConcrete<Output: Dimensionality>(
        @GeometryBuilder<Output> _ action: @Sendable @escaping (D.Concrete) -> Output.Geometry
    ) -> Output.Geometry {
        readingConcrete { concrete, _ in
            action(concrete)
        }
    }
}
