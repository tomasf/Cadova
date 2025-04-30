import Manifold3D
import Foundation

public protocol ConcreteGeometry {
    associatedtype Vector
    associatedtype D: Dimensionality where D.Vector == Vector

    func refine(edgeLength: Double) -> Self
    func allVertices() -> [Vector]
}

extension CrossSection: ConcreteGeometry {
    public typealias D = D2

    public func allVertices() -> [Vector] {
        polygons().flatMap(\.vertices)
    }

    public func refine(edgeLength: Double) -> Self {
        let inputPoints = polygons().map(\.vertices)

        let newPoints = inputPoints.map { points in
            [points[0]] + points.paired().flatMap { from, to -> [Vector2D] in
                let length = from.distance(to: to)
                let segmentCount = ceil(length / edgeLength)
                guard segmentCount > 1 else { return [to] }
                return (1...Int(segmentCount)).map { i in
                    from.point(alongLineTo: to, at: Double(i) / Double(segmentCount))
                }
            }
        }
        return .init(polygons: newPoints.map { Manifold3D.Polygon(vertices: $0) }, fillRule: .nonZero)
    }
}

extension Manifold: ConcreteGeometry {
    public typealias D = D3

    public func allVertices() -> [Vector] {
        meshGL().vertices
    }
}

public typealias Manifold = Manifold3D.Manifold<Vector3D>
public typealias CrossSection = Manifold3D.CrossSection<Vector2D>
public typealias ManifoldPolygon = Manifold3D.Polygon<Vector2D>
public typealias MeshGL = Manifold3D.MeshGL<Vector3D>

extension Vector2D: Manifold3D.Vector2 {}
extension Vector3D: Manifold3D.Vector3 {}

extension AffineTransform2D: Manifold3D.Matrix2x3 {}
extension AffineTransform3D: Manifold3D.Matrix3x4 {}

extension Vector2D {
    public init(_ manifoldVector: any Vector2) {
        self.init(manifoldVector.x, manifoldVector.y)
    }
}

extension Vector3D {
    public init(_ manifoldVector: any Vector3) {
        self.init(manifoldVector.x, manifoldVector.y, manifoldVector.z)
    }
}
