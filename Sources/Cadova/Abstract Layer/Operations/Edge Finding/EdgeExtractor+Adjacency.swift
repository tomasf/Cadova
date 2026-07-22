import Foundation
import Manifold3D

internal extension EdgeExtractor {
    /// Encodes a canonical undirected edge (lo ≤ hi) into a single Int64 for dictionary keying.
    private static func edgeKey(_ a: Int, _ b: Int) -> Int64 {
        let lo = Int32(min(a, b))
        let hi = Int32(max(a, b))
        return (Int64(hi) << 32) | Int64(UInt32(bitPattern: lo))
    }

    struct AdjacentTriangles {
        var first: Int = -1
        var second: Int = -1
        var count: Int = 0

        mutating func append(_ triangleIndex: Int) {
            switch count {
            case 0: first = triangleIndex
            case 1: second = triangleIndex
            default: break
            }
            count += 1
        }
    }

    static func buildAdjacency(triangles: [MeshTriangle], weldedIndex: [Int]) -> [Int64: AdjacentTriangles] {
        var adjacency: [Int64: AdjacentTriangles] = [:]
        adjacency.reserveCapacity(triangles.count * 3 / 2)

        for (triangleIndex, triangle) in triangles.enumerated() {
            let a = weldedIndex[triangle.a]
            let b = weldedIndex[triangle.b]
            let c = weldedIndex[triangle.c]
            guard a != b, b != c, a != c else { continue }
            adjacency[edgeKey(a, b), default: .init()].append(triangleIndex)
            adjacency[edgeKey(b, c), default: .init()].append(triangleIndex)
            adjacency[edgeKey(c, a), default: .init()].append(triangleIndex)
        }

        return adjacency
    }

    static func triangleNormals(vertices: [Vector3D], triangles: [MeshTriangle]) -> [Vector3D?] {
        triangles.map { triangle in
            let v0 = vertices[triangle.a]
            let normal = (vertices[triangle.b] - v0) × (vertices[triangle.c] - v0)
            return normal.magnitude > 1e-12 ? normal.normalized : nil
        }
    }
}
