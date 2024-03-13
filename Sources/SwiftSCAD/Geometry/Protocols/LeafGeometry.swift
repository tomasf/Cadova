import Foundation

public protocol LeafGeometry2D: Geometry2D {
    var invocation: Invocation { get }
    var boundary: Bounds { get }
}

extension LeafGeometry2D {
    public func output(in environment: Environment) -> Output {
        .init(invocation: invocation, boundary: boundary, environment: environment)
    }
}

public protocol LeafGeometry3D: Geometry3D {
    var invocation: Invocation { get }
    var boundary: Bounds { get }
}

extension LeafGeometry3D {
    public func output(in environment: Environment) -> Output {
        .init(invocation: invocation, boundary: boundary, environment: environment)
    }
}
