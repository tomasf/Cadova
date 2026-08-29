import Foundation

/// Defers construction of `body` until build time, so `@Environment` reads inside it resolve to
/// the environment at that point in the tree rather than at construction time.
struct Deferred<D: Dimensionality>: Geometry {
    let body: @Sendable () -> D.Geometry

    init(@GeometryBuilder<D> _ body: @Sendable @escaping () -> D.Geometry) {
        self.body = body
    }

    func _build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> BuildResult<D> {
        try await context.buildResult(for: body(), in: environment)
    }
}
