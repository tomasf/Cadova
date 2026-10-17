import Manifold3D
import Foundation

/// The geometry library type that 2D or 3D geometry evaluates to, which Cadova uses internally.
public protocol ConcreteGeometry {
    associatedtype Vector
    associatedtype D: Dimensionality where D.Vector == Vector

    func refine(edgeLength: Double) -> Self
    func allVertices() -> [Vector]
}

extension Manifold3D.CrossSection<Vector2D>: ConcreteGeometry {
    public typealias D = D2

    public func allVertices() -> [Vector] {
        polygons().flatMap(\.vertices)
    }

    public func refine(edgeLength: Double) -> Self {
        Self(polygonList().refined(maxEdgeLength: edgeLength))
    }
}

extension Manifold3D.Manifold<Vector3D>: ConcreteGeometry {
    public typealias D = D3

    public func allVertices() -> [Vector] {
        meshGL().vertices
    }
}

@_spi(ConcreteInternals) public typealias Manifold = Manifold3D.Manifold<Vector3D>
@_spi(ConcreteInternals) public typealias CrossSection = Manifold3D.CrossSection<Vector2D>
@_spi(ConcreteInternals) public typealias ManifoldPolygon = Manifold3D.Polygon<Vector2D>
@_spi(ConcreteInternals) public typealias MeshGL = Manifold3D.MeshGL<Vector3D>

extension Vector2D: Manifold3D.Vector2 {}
extension Vector3D: Manifold3D.Vector3 {}

extension Transform2D: Manifold3D.Matrix2x3 {}
extension Transform3D: Manifold3D.Matrix3x4 {}

extension Vector2D {
    internal init(_ manifoldVector: any Vector2) {
        self.init(manifoldVector.x, manifoldVector.y)
    }
}

extension Vector3D {
    internal init(_ manifoldVector: any Vector3) {
        self.init(manifoldVector.x, manifoldVector.y, manifoldVector.z)
    }
}

