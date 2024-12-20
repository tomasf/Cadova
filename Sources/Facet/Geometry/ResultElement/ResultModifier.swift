import Foundation

struct ResultModifier<Geometry> {
    let body: Geometry
    let modifier: (ResultElementsByType) -> ResultElementsByType
}

extension ResultModifier<any Geometry2D>: Geometry2D {
    func evaluated(in environment: EnvironmentValues) -> Output2D {
        let bodyOutput = body.evaluated(in: environment)
        return .init(
            manifold: bodyOutput.manifold,
            elements: modifier(bodyOutput.elements)
        )
    }
}

extension ResultModifier<any Geometry3D>: Geometry3D {
    func evaluated(in environment: EnvironmentValues) -> Output3D {
        let bodyOutput = body.evaluated(in: environment)
        return .init(
            manifold: bodyOutput.manifold,
            elements: modifier(bodyOutput.elements)
        )
    }
}


public extension Geometry2D {
    func withResult<E: ResultElement>(_ value: E) -> any Geometry2D {
        ResultModifier(body: self) { elements in
            elements.setting(value)
        }
    }

    func modifyingResult<E: ResultElement>(_ type: E.Type, modification: @escaping (E?) -> E?) -> any Geometry2D {
        ResultModifier(body: self) { elements in
            elements.setting(modification(elements[E.self]))
        }
    }
}

public extension Geometry3D {
    func withResult<E: ResultElement>(_ value: E) -> any Geometry3D {
        ResultModifier(body: self) { elements in
            elements.setting(value)
        }
    }

    func modifyingResult<E: ResultElement>(_ type: E.Type, modification: @escaping (E?) -> E?) -> any Geometry3D {
        ResultModifier(body: self) { elements in
            elements.setting(modification(elements[E.self]))
        }
    }
}
