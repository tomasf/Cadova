import Foundation

public protocol LeafGeometry2D: Geometry2D {
    var invocationName: String { get }
    var invocationParameters: Invocation.Parameters { get }
    var boundary: Bounds { get }
}

extension LeafGeometry2D {
    public func invocation(in environment: Environment) -> Invocation {
        .init(name: invocationName, parameters: invocationParameters, body: [])
    }

    public func anchors(in environment: Environment) -> [Anchor: AffineTransform3D] {
        [:]
    }

    public func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        [:]
    }

    public func boundary(in environment: Environment) -> Bounds {
        boundary
    }
}

public protocol LeafGeometry3D: Geometry3D {
    var invocationName: String { get }
    var invocationParameters: Invocation.Parameters { get }
    var boundary: Bounds { get }
}

extension LeafGeometry3D {
    public func invocation(in environment: Environment) -> Invocation {
        .init(name: invocationName, parameters: invocationParameters, body: [])
    }

    public func anchors(in environment: Environment) -> [Anchor: AffineTransform3D] {
        [:]
    }

    public func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        [:]
    }

    public func boundary(in environment: Environment) -> Bounds {
        boundary
    }
}
