import Foundation
import Manifold3D

public protocol Dimensionality {
    associatedtype Vector: Cadova.Vector where Vector.D == Self
    associatedtype Transform: Cadova.AffineTransform where Transform.D == Self
    associatedtype Axis: Cadova.Axis
    associatedtype Geometry
    associatedtype Primitive: PrimitiveGeometry
    typealias Axes = Set<Axis>
    typealias Alignment = GeometryAlignment<Self>
    typealias Direction = Cadova.Direction<Self>
}

public struct D2: Dimensionality {
    public typealias Vector = Vector2D
    public typealias Transform = AffineTransform2D
    public typealias Axis = Axis2D
    public typealias Geometry = Geometry2D
    public typealias Primitive = CrossSection

    private init() {}
}

public struct D3: Dimensionality {
    public typealias Vector = Vector3D
    public typealias Transform = AffineTransform3D
    public typealias Axis = Axis3D
    public typealias Geometry = Geometry3D
    public typealias Primitive = Manifold

    private init() {}
}
