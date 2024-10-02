import Foundation

extension [Geometry2D]: Geometry2D {
    func body(in environment: Environment) -> any Geometry2D {
        Union2D(children: self)
    }

    public func codeFragment(in environment: Environment) -> CodeFragment {
        body(in: environment).codeFragment(in: environment)
    }

    public func boundary(in environment: Environment) -> Geometry2D.Bounds {
        body(in: environment).boundary(in: environment)
    }

    public func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        body(in: environment).elements(in: environment)
    }
}

extension [Geometry3D]: Geometry3D {
    func body(in environment: Environment) -> any Geometry3D {
        Union3D(children: self)
    }

    public func codeFragment(in environment: Environment) -> CodeFragment {
        body(in: environment).codeFragment(in: environment)
    }

    public func boundary(in environment: Environment) -> Geometry3D.Bounds {
        body(in: environment).boundary(in: environment)
    }

    public func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        body(in: environment).elements(in: environment)
    }
}
