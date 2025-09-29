import Foundation
import Manifold3D

extension GeometryNode {
    public enum PrimitiveShape2D: Hashable, Sendable, Codable {
        case rectangle (size: Vector2D)
        case circle (radius: Double, segmentCount: Int)
        case polygons (SimplePolygonList, fillRule: FillRule)
        case convexHull (points: [Vector2D])
    }

    public enum PrimitiveShape3D: Hashable, Sendable, Codable {
        case box (size: Vector3D)
        case sphere (radius: Double, segmentCount: Int)
        case cylinder (bottomRadius: Double, topRadius: Double, height: Double, segmentCount: Int)
        case convexHull (points: [Vector3D])
        case mesh (MeshData)
    }
}


extension GeometryNode.PrimitiveShape2D {
    func evaluate() -> CrossSection {
        switch self {
        case .rectangle (let size):
            guard size.x > 0, size.y > 0 else { return .empty }
            return CrossSection.square(size: size)

        case .circle (let radius, let segmentCount):
            guard radius >= 0 else { return .empty }
            return CrossSection.circle(radius: radius, segmentCount: segmentCount)

        case .polygons (let list, let fillRule):
            guard list.count > 0 else { return .empty }
            return CrossSection(polygons: list.polygons.map(\.manifoldPolygon), fillRule: fillRule.manifoldRepresentation)

        case .convexHull (let points):
            guard points.count >= 3 else { return .empty }
            return CrossSection.hull(points)
        }
    }
}

extension GeometryNode.PrimitiveShape3D {
    func evaluate() throws -> Manifold {
        switch self {
        case .box (let size):
            guard size.x > 0, size.y > 0, size.z > 0 else { return .empty }
            return Manifold.cube(size: size)

        case .sphere (let radius, let segmentCount):
            guard radius >= 0 else { return .empty }
            return Manifold.sphere(radius: radius, segmentCount: segmentCount)

        case .cylinder (let bottomRadius, let topRadius, let height, let segmentCount):
            guard height >= 0, (bottomRadius >= 0 || topRadius >= 0) else { return .empty }
            return Manifold.cylinder(height: height, bottomRadius: bottomRadius, topRadius: topRadius, segmentCount: segmentCount)

        case .convexHull (let points):
            guard points.count >= 4 else { return .empty }
            return Manifold.hull(points)

        case .mesh (let meshData):
            do {
                return try Manifold(meshData.meshGL()).asOriginal()
            } catch ManifoldError.notManifold {
                throw MeshNotManifoldError()
            }
        }
    }
}

struct MeshNotManifoldError: LocalizedError {
    var errorDescription: String? {
"""
Mesh creation failed: The mesh is not manifold.

This means some edges or vertices are shared in a way that makes the shape ambiguous or invalid for solid geometry. 
Common causes include:
- Holes or missing faces
- Edges shared by more than two faces
- Non-contiguous face loops
- Duplicate or misordered vertices

Ensure that your mesh defines a closed, watertight surface where every edge is shared by exactly two faces, and all
faces have consistent winding. Try visualizedForDebugging() to visualize the faces of a mesh without requiring it to
be manifold.
"""
    }
}
