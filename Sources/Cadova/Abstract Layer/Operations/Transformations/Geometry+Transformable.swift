import Foundation

public extension Geometry {
    /// Applies a given affine transformation to the geometry.
    /// - Parameter transform: The transformation to be applied.
    /// - Returns: A transformed `Geometry`.
    func transformed(_ transform: D.Transform) -> D.Geometry {
        if transform.isIdentity {
            return self
        } else if let innerTransformer = self as? ApplyTransform<D>,
                  innerTransformer.transformEnvironment {
            return ApplyTransform(
                body: innerTransformer.body,
                transform: innerTransformer.transform.transformed(transform),
                transformEnvironment: true
            )
        } else {
            return ApplyTransform(body: self, transform: transform)
        }
    }
}

internal struct ApplyTransform<D: Dimensionality>: Geometry {
    let body: D.Geometry
    let transform: D.Transform
    let transformEnvironment: Bool

    init(
        body: D.Geometry,
        transform: D.Transform,
        transformEnvironment: Bool = true
    ) {
        self.body = body
        self.transform = transform
        self.transformEnvironment = transformEnvironment
    }

    func _build(in environment: EnvironmentValues, context: _EvaluationContext) async throws -> D._BuildResult {
        let environment = if transformEnvironment {
            environment.applyingTransform(transform.transform3D)
        } else {
            environment
        }

        return try await context.buildResult(for: body, in: environment)
            .applyingTransform(transform)
    }
}
