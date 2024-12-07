import Foundation
import Manifold

public protocol Dimensionality {
    associatedtype Vector: Facet.Vector
    associatedtype Transform: Facet.AffineTransform
    associatedtype Axis: Facet.Axis
    associatedtype Axes
    associatedtype Geometry
    associatedtype ManifoldType
}

public struct Dimensionality2: Dimensionality {
    public typealias Vector = Vector2D
    public typealias Transform = AffineTransform2D
    public typealias Axis = Axis2D
    public typealias Axes = Axes2D
    public typealias Geometry = Geometry2D
    public typealias ManifoldType = CrossSection

    private init() {}
}

public struct Dimensionality3: Dimensionality {
    public typealias Vector = Vector3D
    public typealias Transform = AffineTransform3D
    public typealias Axis = Axis3D
    public typealias Axes = Axes3D
    public typealias Geometry = Geometry3D
    public typealias ManifoldType = Mesh

    private init() {}
}
