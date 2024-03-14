import Foundation

public protocol LeafGeometry2D: Geometry2D {
    var invocation: Invocation { get }
    func boundary(in environment: Environment) -> Bounds
}

extension LeafGeometry2D {
    public func output(in environment: Environment) -> Output {
        .init(
            invocation: invocation,
            boundary: boundary(in: environment),
            environment: environment
        )
    }
}

public protocol LeafGeometry3D: Geometry3D {
    var invocation: Invocation { get }
    func boundary(in environment: Environment) -> Bounds
}

extension LeafGeometry3D {
    public func output(in environment: Environment) -> Output {
        .init(
            invocation: invocation,
            boundary: boundary(in: environment),
            environment: environment
        )
    }
}
