import Foundation
import Manifold3D

internal extension EdgeExtractor {
    /// Maps each vertex index to a canonical index, merging vertices at identical positions.
    /// Meshes can contain duplicate vertices (e.g. from property boundaries); without welding,
    /// edges between them would appear to border only one triangle and be missed.
    static func weldVertices(_ vertices: [Vector3D]) -> [Int] {
        var canonical: [Vector3D: Int] = [:]
        canonical.reserveCapacity(vertices.count)
        return vertices.indices.map { index in
            if let existing = canonical[vertices[index]] {
                return existing
            } else {
                canonical[vertices[index]] = index
                return index
            }
        }
    }
}
