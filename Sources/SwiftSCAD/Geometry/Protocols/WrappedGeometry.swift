import Foundation

protocol WrappedGeometry2D: Geometry2D {
    var body: any Geometry2D { get }
    func modifiedEnvironment(_ environment: Environment) -> Environment
    var moduleName: String? { get }
    var moduleParameters: CodeFragment.Parameters { get }
}

extension WrappedGeometry2D {
    internal func bodyEnvironment(_ environment: Environment) -> Environment {
        modifiedEnvironment(environment)
    }

    func codeFragment(in environment: Environment) -> CodeFragment {
        if let moduleName {
            CodeFragment(module: moduleName, parameters: moduleParameters, body: [body.codeFragment(in: bodyEnvironment(environment))])
        } else {
            body.codeFragment(in: bodyEnvironment(environment))
        }
    }

    func boundary(in environment: Environment) -> Bounds {
        body.boundary(in: bodyEnvironment(environment))
    }

    func anchors(in environment: Environment) -> [Anchor: AffineTransform3D] {
        body.anchors(in: bodyEnvironment(environment))
    }

    func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        body.elements(in: bodyEnvironment(environment))
    }

    func modifiedEnvironment(_ environment: Environment) -> Environment {
        environment
    }

    public var moduleName: String? { nil }
    public var moduleParameters: CodeFragment.Parameters { [:] }
}

protocol WrappedGeometry3D: Geometry3D {
    var body: any Geometry3D { get }
    var bodyTransform: AffineTransform3D { get }
    func modifiedEnvironment(_ environment: Environment) -> Environment
    var moduleName: String? { get }
    var moduleParameters: CodeFragment.Parameters { get }
}

extension WrappedGeometry3D {
    public var bodyTransform: AffineTransform3D { .identity }

    internal func bodyEnvironment(_ environment: Environment) -> Environment {
        modifiedEnvironment(environment.applyingTransform(bodyTransform))
    }

    func codeFragment(in environment: Environment) -> CodeFragment {
        if let moduleName {
            CodeFragment(module: moduleName, parameters: moduleParameters, body: [body.codeFragment(in: bodyEnvironment(environment))])
        } else {
            body.codeFragment(in: bodyEnvironment(environment))
        }
    }

    func boundary(in environment: Environment) -> Bounds {
        body.boundary(in: bodyEnvironment(environment))
    }

    func anchors(in environment: Environment) -> [Anchor: AffineTransform3D] {
        body.anchors(in: bodyEnvironment(environment))
    }

    func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        body.elements(in: bodyEnvironment(environment))
    }

    func modifiedEnvironment(_ environment: Environment) -> Environment { environment }

    public var moduleName: String? { nil }
    public var moduleParameters: CodeFragment.Parameters { [:] }
}
