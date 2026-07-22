import Foundation
import Manifold3D

internal extension EdgeExtractor {
    /// Maps each distinct vertex position to whether it lies inside `manifold`, treated as a solid.
    static func maskContainment(of vertices: [Vector3D], in manifold: Manifold) -> [Vector3D: Bool] {
        var result: [Vector3D: Bool] = [:]
        for vertex in vertices where result[vertex] == nil {
            result[vertex] = contains(vertex, in: manifold)
        }
        return result
    }

    /// A point-in-solid test via ray-cast parity: an odd number of surface crossings between the
    /// point and a point known to be outside the manifold means the point is inside.
    ///
    /// Ray-casting is BVH-accelerated (the same primitive `readingSurfaces` uses), so this is cheap
    /// once per distinct point; the escape direction is an arbitrary skewed vector, chosen to make
    /// the ray graze along a mesh face or edge unlikely.
    private static let escapeDirection = Direction3D(x: 0.5231, y: 0.6180, z: 0.5878)

    private static func contains(_ point: Vector3D, in manifold: Manifold) -> Bool {
        guard !manifold.isEmpty else { return false }
        let bounds = BoundingBox3D(manifold.bounds)
        guard bounds.contains(point) else { return false }
        let segment = bounds.coveringSegment(from: point, in: escapeDirection)
        let hits = manifold.rayCast(from: segment.start, to: segment.end)
        return hits.count % 2 == 1
    }
}
