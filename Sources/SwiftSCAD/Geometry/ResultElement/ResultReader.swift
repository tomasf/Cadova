import Foundation

internal struct ResultReader2D: Geometry2D {
    let body: any Geometry2D
    let generator: (ResultElementsByType) -> any Geometry2D

    func body(in environment: Environment) -> any Geometry2D {
        generator(body.elements(in: environment))
    }

    func codeFragment(in environment: Environment) -> CodeFragment {
        body(in: environment).codeFragment(in: environment)
    }

    func boundary(in environment: Environment) -> Bounds {
        body(in: environment).boundary(in: environment)
    }

    func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        body(in: environment).elements(in: environment)
    }
}

public extension Geometry2D {
    func readingResult<E: ResultElement>(_ type: E.Type, @GeometryBuilder2D generator: @escaping (_ body: any Geometry2D, _ value: E?) -> any Geometry2D) -> any Geometry2D {
        ResultReader2D(body: self) { elements in
            generator(self, elements[type])
        }
    }
}

internal struct ResultReader3D: Geometry3D {
    let body: any Geometry3D
    let generator: (ResultElementsByType) -> any Geometry3D

    func body(in environment: Environment) -> any Geometry3D {
        generator(body.elements(in: environment))
    }

    func codeFragment(in environment: Environment) -> CodeFragment {
        body(in: environment).codeFragment(in: environment)
    }

    func boundary(in environment: Environment) -> Bounds {
        body(in: environment).boundary(in: environment)
    }

    func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        body(in: environment).elements(in: environment)
    }
}

public extension Geometry3D {
    func readingResult<E: ResultElement>(_ type: E.Type, @GeometryBuilder3D generator: @escaping (_ body: any Geometry3D, _ value: E?) -> any Geometry3D) -> any Geometry3D {
        ResultReader3D(body: self) { elements in
            generator(self, elements[type])
        }
    }
}
