import Foundation

struct ResultModifier<Geometry> {
    let body: Geometry
    let modifier: (ResultElementsByType) -> ResultElementsByType
}

extension ResultModifier<any Geometry2D>: Geometry2D {
    func evaluated(in environment: Environment) -> Output2D {
        let bodyOutput = body.evaluated(in: environment)
        return .init(
            codeFragment: bodyOutput.codeFragment,
            boundary: bodyOutput.boundary,
            elements: modifier(bodyOutput.elements)
        )
    }
}

extension ResultModifier<any Geometry3D>: Geometry3D {
    func evaluated(in environment: Environment) -> Output3D {
        let bodyOutput = body.evaluated(in: environment)
        return .init(
            codeFragment: bodyOutput.codeFragment,
            boundary: bodyOutput.boundary,
            elements: modifier(bodyOutput.elements)
        )
    }
}


public extension Geometry2D {
    func withResult<E: ResultElement>(_ value: E) -> any Geometry2D {
        ResultModifier(body: self) { elements in
            elements.setting(E.self, to: value)
        }
    }

    func modifyingResult<E: ResultElement>(_ type: E.Type, modification: @escaping (E?) -> E?) -> any Geometry2D {
        ResultModifier(body: self) { elements in
            elements.setting(E.self, to: modification(elements[E.self]))
        }
    }
}

public extension Geometry3D {
    func withResult<E: ResultElement>(_ value: E) -> any Geometry3D {
        ResultModifier(body: self) { elements in
            elements.setting(E.self, to: value)
        }
    }

    func modifyingResult<E: ResultElement>(_ type: E.Type, modification: @escaping (E?) -> E?) -> any Geometry3D {
        ResultModifier(body: self) { elements in
            elements.setting(E.self, to: modification(elements[E.self]))
        }
    }
}
