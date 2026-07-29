import Foundation

internal struct ResultReader<Input: Dimensionality, Output: Dimensionality>: Geometry {
    let source: Input.Geometry
    let generator: @Sendable (ResultElements) -> Output.Geometry

    func _build(in environment: EnvironmentValues, context: _EvaluationContext) async throws -> Output._BuildResult {
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
