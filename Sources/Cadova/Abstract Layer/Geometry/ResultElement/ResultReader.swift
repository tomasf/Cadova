import Foundation

internal struct ResultReader<Input: Dimensionality, Output: Dimensionality>: Geometry {
    let body: Input.Geometry
    let generator: @Sendable (ResultElements) -> Output.Geometry

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> Output.BuildResult {
        let bodyResult = try await body.build(in: environment, context: context)
        return await try generator(bodyResult.elements).build(in: environment, context: context)
    }
}

public extension Geometry {
    func readingResult<E: ResultElement, Output: Dimensionality>(
        _ type: E.Type,
        @GeometryBuilder<Output> generator: @Sendable @escaping (D.Geometry, E) -> Output.Geometry
    ) -> Output.Geometry {
        ResultReader(body: self) { elements in
            generator(self, elements[type])
        }
    }
}
