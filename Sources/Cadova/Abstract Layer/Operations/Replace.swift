import Foundation

public extension Geometry {
    func replaced(
        if condition: Bool,
        @GeometryBuilder<D> with replacement: @Sendable @escaping (_ input: D.Geometry) -> D.Geometry
    ) -> D.Geometry {
        if condition {
            Replace(source: self, replacement: replacement(self))
        } else {
            self
        }
    }

    func replaced<T: Sendable>(
        if optional: T?,
        @GeometryBuilder<D> with replacement: @Sendable @escaping (_ input: D.Geometry, _ value: T) -> D.Geometry
    ) -> D.Geometry {
        if let optional {
            Replace(source: self, replacement: replacement(self, optional))
        } else {
            self
        }
    }

    func replaced<Output: Dimensionality>(
        @GeometryBuilder<Output> with replacement: @Sendable @escaping (_ input: D.Geometry) -> Output.Geometry
    ) -> Output.Geometry {
        Replace(source: self, replacement: replacement(self))
    }
}

internal struct Replace<D: Dimensionality, Input: Dimensionality>: Geometry {
    let source: Input.Geometry
    let replacement: D.Geometry

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        let sourceResult = try await context.buildResult(for: source, in: environment)
        let replacementResult = try await context.buildResult(for: replacement, in: environment)
        return replacementResult.mergingElements(sourceResult.elements)
    }
}
