import Foundation

struct ResultModifier<D: Dimensionality>: Geometry {
    let body: D.Geometry
    let modifier: @Sendable (ResultElements) -> ResultElements

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        let bodyResult = try await context.buildResult(for: body, in: environment)
        return bodyResult.replacing(elements: modifier(bodyResult.elements))
    }
}

struct ResultAndGeometryModifier<D: Dimensionality>: Geometry {
    let body: D.Geometry
    let modifier: @Sendable (ResultElements) -> (D.Geometry, ResultElements)

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        let bodyResult = try await context.buildResult(for: body, in: environment)
        let (newBody, elements) = modifier(bodyResult.elements)
        let newBodyResult = try await context.buildResult(for: newBody, in: environment)
        return newBodyResult.replacing(elements: elements)
    }
}

public extension Geometry {
    func withResult<E: ResultElement>(_ value: E) -> D.Geometry {
        ResultModifier(body: self) { elements in
            elements.setting(value)
        }
    }

    func modifyingResult<E: ResultElement>(
        _ type: E.Type,
        modifier: @Sendable @escaping (inout E) -> Void
    ) -> D.Geometry {
        ResultModifier(body: self) { elements in
            var element = elements[E.self]
            modifier(&element)
            return elements.setting(element)
        }
    }
}

internal extension Geometry {
    func mergingResultElements(with otherElements: ResultElements) -> D.Geometry {
        ResultModifier(body: self) { elements in
            ResultElements(combining: [elements, otherElements])
        }
    }

    func modifyingResult<E: ResultElement>(
        _ type: E.Type,
        @GeometryBuilder<D3> modifier: @Sendable @escaping (D.Geometry, inout E) -> D.Geometry
    ) -> D.Geometry {
        ResultAndGeometryModifier(body: self) { elements in
            var element = elements[E.self]
            let geometry = modifier(self, &element)
            return (geometry, elements.setting(element))
        }
    }
}
