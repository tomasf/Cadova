import Foundation
import Manifold3D

public protocol Dimensionality {
    associatedtype Expression: GeometryExpression where Expression.D == Self
    associatedtype Primitive: Manifold3D.Geometry, PrimitiveGeometry where Primitive.D == Self
    associatedtype Vector: Cadova.Vector where Vector.D == Self
    associatedtype Transform: Cadova.AffineTransform where Transform.D == Self
    associatedtype Axis: Cadova.Axis

    typealias Geometry = any Cadova.Geometry<Self>
    typealias Axes = Set<Axis>
    typealias Alignment = GeometryAlignment<Self>
    typealias Direction = Cadova.Direction<Self>
    typealias Result = GeometryResult<Self>
    typealias Measurements = Cadova.Measurements<Self>
    typealias BoundingBox = Cadova.BoundingBox<Self>
}

// 2D-related types
public struct D2: Dimensionality {
    public typealias Vector = Vector2D
    public typealias Transform = AffineTransform2D
    public typealias Axis = Axis2D
    public typealias Primitive = CrossSection
    public typealias Expression = GeometryExpression2D

    private init() {}
}

// 3D-related types
public struct D3: Dimensionality {
    public typealias Vector = Vector3D
    public typealias Transform = AffineTransform3D
    public typealias Axis = Axis3D
    public typealias Primitive = Manifold
    public typealias Expression = GeometryExpression3D

    private init() {}
}
