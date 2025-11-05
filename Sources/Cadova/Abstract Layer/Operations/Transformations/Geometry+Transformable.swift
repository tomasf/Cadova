import Foundation

public extension Geometry {
    /// Applies a given affine transformation to the geometry.
    /// - Parameter transform: The transformation to be applied.
    /// - Returns: A transformed `Geometry`.
    func transformed(_ transform: D.Transform) -> D.Geometry {
        ApplyTransform(body: self, transform: transform)
    }
}

internal struct ApplyTransform<D: Dimensionality>: Geometry {
    let body: D.Geometry
    let transform: D.Transform

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        try await context.buildResult(for: body, in: environment.applyingTransform(transform.transform3D))
            .applyingTransform(transform)
    }
}
