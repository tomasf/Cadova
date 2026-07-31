import Foundation

/// Builds `body`, then discards its shape while keeping its other result elements (parts, tags,
/// etc.) intact. Powers the `hidden()` modifier.
struct Hidden<D: Dimensionality>: Geometry {
    let body: D.Geometry

    func _build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        let bodyResult = try await context.buildResult(for: body, in: environment)
        return bodyResult.replacing(node: .empty)
    }
}

public extension Geometry {
    /// Returns geometry that behaves like this geometry but produces no shape.
    ///
    /// The result keeps everything else about this geometry, its parts, tags, and other result
    /// elements, but its shape is replaced with empty geometry.
    func hidden() -> D.Geometry {
        Hidden<D>(body: self)
    }
}
