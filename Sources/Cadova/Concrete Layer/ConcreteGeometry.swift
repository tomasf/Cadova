import Manifold3D
import Foundation
import CadovaCPP

public protocol ConcreteGeometry {
    associatedtype Vector
    associatedtype D: Dimensionality where D.Vector == Vector

    func refine(edgeLength: Double) -> Self
    func allVertices() -> [Vector]
    func baked() -> Self
}

extension CrossSection: ConcreteGeometry {
    public typealias D = D2

    public func allVertices() -> [Vector] {
        polygons().flatMap(\.vertices)
    }

    public func refine(edgeLength: Double) -> Self {
        Self(polygonList().refined(maxEdgeLength: edgeLength))
    }

    public func baked() -> Self {
        _ = vertexCount
        return self
    }
}

extension Manifold: ConcreteGeometry {
    public typealias D = D3

    public func allVertices() -> [Vector] {
        meshGL().vertices
    }

    public func baked() -> Self {
        _ = vertexCount
        return self
    }
}

public typealias Manifold = Manifold3D.Manifold<Vector3D>
public typealias CrossSection = Manifold3D.CrossSection<Vector2D>
public typealias ManifoldPolygon = Manifold3D.Polygon<Vector2D>
public typealias MeshGL = Manifold3D.MeshGL<Vector3D>

extension Vector2D: Manifold3D.Vector2 {}
extension Vector3D: Manifold3D.Vector3 {}

extension Transform2D: Manifold3D.Matrix2x3 {}
extension Transform3D: Manifold3D.Matrix3x4 {}

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

extension Manifold {
    func readMesh() -> (vertices: [Vector3D], triangles: [Manifold3D.Triangle], originalIDs: [Manifold.OriginalID: IndexSet]) {
        var vertices: [Vector3D] = []
        var triangles: [Manifold3D.Triangle] = []
        var originalIDs: [Manifold.OriginalID: IndexSet] = [:]

        cadova.BulkReadMesh(mesh, { properties, vertexCount, propertyCount in
            guard let properties else { return }
            for i in 0..<vertexCount {
                vertices.append(Vector3D(properties[propertyCount * i], properties[propertyCount * i + 1], properties[propertyCount * i + 2]))
            }
        }, { indices, triangleCount in
            guard let indices else { return }
            for i in 0..<triangleCount {
                triangles.append(Manifold3D.Triangle(Int(indices[i * 3]), Int(indices[i * 3 + 1]), Int(indices[i * 3 + 2])))
            }

        }, { runIndex, runIndexCount, runOriginalIDs, runOriginalIDCount in
            guard let runIndex, let runOriginalIDs else { return }

            let ranges = (0..<runIndexCount).paired().map { index1, index2 in
                Int(runIndex[index1] / 3)..<Int(runIndex[index2] / 3)
            }
            originalIDs = ranges.enumerated().reduce(into: [:]) { result, item in
                let originalID = Int(runOriginalIDs[item.offset])
                result[originalID, default: IndexSet()].insert(integersIn: item.element)
            }
        })

        return (vertices, triangles, originalIDs)
    }
}
