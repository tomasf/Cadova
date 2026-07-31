import Foundation

/// Builds `source`, then hands its result elements to `generator` to construct the geometry that's
/// actually returned — possibly with a different dimensionality than `source`. Powers
/// `readingResult(_:generator:)`, which lets callers inspect a typed result element (e.g. a part
/// catalog) produced while building another geometry.
internal struct ResultReader<Input: Dimensionality, Output: Dimensionality>: Geometry {
    let source: Input.Geometry
    let generator: @Sendable (ResultElements) -> Output.Geometry

    func _build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> Output.BuildResult {
        let sourceResult = try await context.buildResult(for: source, in: environment)
        return try await context.buildResult(for: generator(sourceResult.elements), in: environment)
    }
}

public extension Geometry {
    func readingResult<E: ResultElement, Output: Dimensionality>(
        _ type: E.Type,
        @GeometryBuilder<Output> generator: @Sendable @escaping (D.Geometry, E) -> Output.Geometry
    ) -> Output.Geometry {
        ResultReader(source: self) { elements in
            generator(self, elements[type])
        }
    }
}
