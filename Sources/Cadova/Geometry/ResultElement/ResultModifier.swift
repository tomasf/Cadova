import Foundation

struct ResultModifier<D: Dimensionality>: Geometry {
    let body: D.Geometry
    let modifier: @Sendable (ResultElementsByType) -> ResultElementsByType

    func build(in environment: EnvironmentValues, context: EvaluationContext) async -> D.Result {
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

    func modifyingResult<E: ResultElement>(_ type: E.Type, modification: @Sendable @escaping (E?) -> E?) -> D.Geometry {
        ResultModifier(body: self) { elements in
            elements.setting(modification(elements[E.self]))
        }
    }
}
