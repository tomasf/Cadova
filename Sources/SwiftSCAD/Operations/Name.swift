import Foundation

public enum TransformContext {
    case global
    case local
}

struct NameGeometry2D: Geometry2D {
    let body: any Geometry2D
    let name: String
    let transform: TransformContext

    func codeFragment(in environment: Environment) -> CodeFragment {
        body.codeFragment(in: environment)
    }

    func boundary(in environment: Environment) -> Bounds {
        body.boundary(in: environment)
    }

    func anchors(in environment: Environment) -> [Anchor: AffineTransform3D] {
        body.anchors(in: environment)
    }

    func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        let elements = body.elements(in: environment)
        let namedGeometry = elements[NamedGeometry.self] ?? .init()
        return elements.setting(NamedGeometry.self, to: namedGeometry.adding(body, named: name))
    }
}

struct NameGeometry3D: Geometry3D {
    let body: any Geometry3D
    let name: String
    let transform: TransformContext

    func codeFragment(in environment: Environment) -> CodeFragment {
        body.codeFragment(in: environment)
    }

    func boundary(in environment: Environment) -> Bounds {
        body.boundary(in: environment)
    }

    func anchors(in environment: Environment) -> [Anchor: AffineTransform3D] {
        body.anchors(in: environment)
    }

    func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        let elements = body.elements(in: environment)
        let namedGeometry = elements[NamedGeometry.self] ?? .init()
        return elements.setting(NamedGeometry.self, to: namedGeometry.adding(body, named: name))
    }
}

public extension Geometry2D {
    func named(_ name: String, transform: TransformContext = .global) -> any Geometry2D {
        NameGeometry2D(body: self, name: name, transform: transform)
    }
}

public extension Geometry3D {
    func named(_ name: String, transform: TransformContext = .global) -> any Geometry3D {
        NameGeometry3D(body: self, name: name, transform: transform)
    }
}
