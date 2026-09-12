import Foundation
import Manifold3D

extension GeometryNode {
    internal enum PrimitiveShape2D: Hashable, Sendable, Codable {
        case rectangle (size: Vector2D)
        case circle (radius: Double, segmentCount: Int)
        case polygons (SimplePolygonList, fillRule: FillRule)
        case convexHull (points: [Vector2D])
    }

    internal enum PrimitiveShape3D: Hashable, Sendable, Codable {
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
            guard radius > 0 else { return .empty }
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
    /// The shape as a solid. A mesh carries its face materials along in the result's material mapping.
    func evaluate() throws -> EvaluationResult<D3> {
        switch self {
        case .box (let size):
            guard size.x > 0, size.y > 0, size.z > 0 else { return .empty }
            return try EvaluationResult(Manifold.cube(size: size))

        case .sphere (let radius, let segmentCount):
            guard radius > 0 else { return .empty }
            return try EvaluationResult(Manifold.sphere(radius: radius, segmentCount: segmentCount))

        case .cylinder (let bottomRadius, let topRadius, let height, let segmentCount):
            guard height > 0, (bottomRadius > 0 || topRadius > 0) else { return .empty }
            return try EvaluationResult(
                Manifold.cylinder(height: height, bottomRadius: bottomRadius, topRadius: topRadius, segmentCount: segmentCount)
            )

        case .convexHull (let points):
            guard points.count >= 4 else { return .empty }
            return try EvaluationResult(Manifold.hull(points))

        case .mesh (let meshData):
            return try meshData.evaluate()
        }
    }
}
