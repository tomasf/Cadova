import Foundation

struct ResultModifier<D: Dimensionality>: Geometry {
    let body: D.Geometry
    let modifier: @Sendable (ResultElements) -> ResultElements

    func build(in environment: EnvironmentValues, context: EvaluationContext) async -> D.BuildResult {
        let bodyResult = await body.build(in: environment, context: context)
        return bodyResult.replacing(elements: modifier(bodyResult.elements))
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
}
