import Foundation

public enum TransformContext {
    case global
    case local
}

struct NameGeometry2D: Geometry2D {
    let body: any Geometry2D
    let name: String
    let transform: TransformContext

    func output(in environment: Environment) -> Output {
        let t: AffineTransform2D = transform == .global ? .init(environment.transform) : .identity
        return body.output(in: environment).naming(body.transformed(t), name)
    }
}

struct NameGeometry3D: Geometry3D {
    let body: any Geometry3D
    let name: String
    let transform: TransformContext

    func output(in environment: Environment) -> Output {
        let t: AffineTransform3D = transform == .global ? environment.transform : .identity
        return body.output(in: environment).naming(body.transformed(t), name)
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
