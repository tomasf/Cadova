import Foundation
import Manifold3D

/// A marker protocol that distinguishes between 2D and 3D geometry.
///
/// This protocol is part of Cadova's internal type system and is not intended for direct use.
/// It provides associated types that vary between two and three dimensions, enabling
/// type-safe operations that work generically across both.
///
/// - SeeAlso: ``D2`` for 2D geometry, ``D3`` for 3D geometry.
///
public protocol Dimensionality: SendableMetatype {
    typealias Geometry = any Cadova.Geometry<Self>
    associatedtype Concrete: Manifold3D.Geometry, ConcreteGeometry where Concrete.D == Self

    associatedtype Vector: Cadova.Vector where Vector.D == Self
    associatedtype Transform: Cadova.Transform where Transform.D == Self
    associatedtype Axis: Cadova.Axis where Axis.D == Self

    typealias Axes = Set<Axis>
    typealias Line = Cadova.Line<Self>
    typealias Alignment = GeometryAlignment<Self>
    typealias Direction = Cadova.Direction<Self>
    typealias BuildResult = Cadova.BuildResult<Self>
    typealias Measurements = Cadova.Measurements<Self>
    typealias BoundingBox = Cadova.BoundingBox<Self>

    static func box(size: Vector, at origin: Vector) -> Geometry
}

internal extension Dimensionality {
    typealias Node = GeometryNode<Self>
    typealias Curve = ParametricCurve<Vector>
}

/// The two-dimensional space.
///
/// `D2` is a marker type used by Cadova's type system to distinguish 2D geometry from 3D.
/// You typically don't interact with this type directly; instead, use concrete 2D types
/// like ``Circle``, ``Rectangle``, or ``Polygon``.
///
public struct D2: Dimensionality {
    public typealias Concrete = CrossSection

    public typealias Vector = Vector2D
    public typealias Transform = Transform2D
    public typealias Axis = Axis2D

    public static func box(size: Vector2D, at origin: Vector2D) -> any Geometry2D {
        Rectangle(size).translated(origin)
    }

    private init() {}
}

/// The three-dimensional space.
///
/// `D3` is a marker type used by Cadova's type system to distinguish 3D geometry from 2D.
/// You typically don't interact with this type directly; instead, use concrete 3D types
/// like ``Box``, ``Sphere``, or ``Cylinder``.
///
public struct D3: Dimensionality {
    public typealias Concrete = Manifold

    public typealias Vector = Vector3D
    public typealias Transform = Transform3D
    public typealias Axis = Axis3D

    public static func box(size: Vector3D, at origin: Vector3D) -> any Geometry3D {
        Box(size).translated(origin)
    }

    private init() {}
}
