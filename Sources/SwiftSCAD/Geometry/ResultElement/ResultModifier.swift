import Foundation

struct ResultModifier<Geometry> {
    let body: Geometry
    let modifier: (ResultElementsByType) -> ResultElementsByType
}

extension ResultModifier<any Geometry2D>: Geometry2D {
    func codeFragment(in environment: Environment) -> CodeFragment {
        body.codeFragment(in: environment)
    }

    func boundary(in environment: Environment) -> Boundary2D {
        body.boundary(in: environment)
    }

    func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        modifier(body.elements(in: environment))
    }
}

extension ResultModifier<any Geometry3D>: Geometry3D {
    func codeFragment(in environment: Environment) -> CodeFragment {
        body.codeFragment(in: environment)
    }

    func boundary(in environment: Environment) -> Boundary3D {
        body.boundary(in: environment)
    }

    func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        modifier(body.elements(in: environment))
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
