import Foundation
import Manifold3D

public protocol Dimensionality {
    typealias Geometry = any Cadova.Geometry<Self>
    associatedtype Concrete: Manifold3D.Geometry, ConcreteGeometry where Concrete.D == Self

    associatedtype Vector: Cadova.Vector where Vector.D == Self
    associatedtype Transform: Cadova.AffineTransform where Transform.D == Self
    associatedtype Axis: Cadova.Axis

    typealias Axes = Set<Axis>
    typealias Alignment = GeometryAlignment<Self>
    typealias Direction = Cadova.Direction<Self>
    typealias BuildResult = Cadova.BuildResult<Self>
    typealias Measurements = Cadova.Measurements<Self>
    typealias BoundingBox = Cadova.BoundingBox<Self>
}

internal extension Dimensionality {
    typealias Node = GeometryNode<Self>
}

// 2D-related types
public struct D2: Dimensionality {
    public typealias Concrete = CrossSection

    public typealias Vector = Vector2D
    public typealias Transform = AffineTransform2D
    public typealias Axis = Axis2D

    private init() {}
}

// 3D-related types
public struct D3: Dimensionality {
    public typealias Concrete = Manifold

    public typealias Vector = Vector3D
    public typealias Transform = AffineTransform3D
    public typealias Axis = Axis3D

    private init() {}
}
