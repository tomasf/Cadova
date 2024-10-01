import Foundation

internal protocol WrappedGeometry2D: Geometry2D {
    var body: any Geometry2D { get }
    var moduleName: String? { get }
    var moduleParameters: CodeFragment.Parameters { get }
}

extension WrappedGeometry2D {
    func codeFragment(in environment: Environment) -> CodeFragment {
        let bodyFragment = body.codeFragment(in: environment)
        if let moduleName {
            return CodeFragment(module: moduleName, parameters: moduleParameters, body: [bodyFragment])
        } else {
            return bodyFragment
        }
    }

    func boundary(in environment: Environment) -> Bounds {
        body.boundary(in: environment)
    }

    func anchors(in environment: Environment) -> [Anchor: AffineTransform3D] {
        body.anchors(in: environment)
    }

    func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        body.elements(in: environment)
    }

    public var moduleName: String? { nil }
    public var moduleParameters: CodeFragment.Parameters { [:] }
}

internal protocol WrappedGeometry3D: Geometry3D {
    var body: any Geometry3D { get }
    var moduleName: String? { get }
    var moduleParameters: CodeFragment.Parameters { get }
}

extension WrappedGeometry3D {
    func codeFragment(in environment: Environment) -> CodeFragment {
        let bodyFragment = body.codeFragment(in: environment)
        if let moduleName {
            return CodeFragment(module: moduleName, parameters: moduleParameters, body: [bodyFragment])
        } else {
            return bodyFragment
        }
    }

    func boundary(in environment: Environment) -> Bounds {
        body.boundary(in: environment)
    }

    func anchors(in environment: Environment) -> [Anchor: AffineTransform3D] {
        body.anchors(in: environment)
    }

    func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        body.elements(in: environment)
    }

    public var moduleName: String? { nil }
    public var moduleParameters: CodeFragment.Parameters { [:] }
}
