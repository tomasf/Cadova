import Foundation
import Manifold3D

internal extension EdgeExtractor {
    struct SharpEdge {
        let vertexA: Int              // welded start vertex index
        let vertexB: Int              // welded end vertex index
        let normalLeft: Direction3D   // outward normal of the left face when traveling A→B
        let normalRight: Direction3D  // outward normal of the right face when traveling A→B
        let isConvex: Bool
    }

    static func findSharpEdges(
        vertices: [Vector3D],
        triangles: [MeshTriangle],
        normals: [Vector3D?],
        weldedIndex: [Int],
        adjacency: [Int64: AdjacentTriangles],
        threshold: Angle,
        maximumThreshold: Angle?
    ) -> [SharpEdge] {
        // For outward-pointing face normals:
        //   flat edge  → normals are parallel → dot ≈ +1
        //   sharp edge → normals diverge      → dot ≤ cos(threshold)
        // Since dot = cos(deviation), a maximum deviation bound becomes a lower bound on dot.
        let cosThreshold = cos(threshold)
        let cosMaximumThreshold = maximumThreshold.map(cos)

        var result: [SharpEdge] = []
        result.reserveCapacity(adjacency.count / 8)

        for (key, adjacent) in adjacency {
            guard adjacent.count == 2,
                  let normal0 = normals[adjacent.first],
                  let normal1 = normals[adjacent.second]
            else { continue }

            let dot = normal0 ⋅ normal1
            guard dot <= cosThreshold, cosMaximumThreshold.map({ dot >= $0 }) ?? true else { continue }

            let lo = Int(Int32(truncatingIfNeeded: key))
            let hi = Int(Int32(truncatingIfNeeded: key >> 32))

            // If hi follows lo in the first triangle's counterclockwise winding, that triangle
            // is the left face when traveling lo→hi; otherwise it's the right face.
            let (normalLeft, normalRight) = firstTriangleIsLeftFace(
                of: (lo, hi), triangle: triangles[adjacent.first], weldedIndex: weldedIndex
            ) ? (normal0, normal1) : (normal1, normal0)

            let direction = vertices[hi] - vertices[lo]
            result.append(SharpEdge(
                vertexA: lo,
                vertexB: hi,
                normalLeft: Direction3D(normalLeft),
                normalRight: Direction3D(normalRight),
                isConvex: ((normalLeft × normalRight) ⋅ direction) > 0
            ))
        }

        // Dictionary iteration order is nondeterministic; sort so that chain construction,
        // and therefore output order, is stable across runs.
        result.sort { ($0.vertexA, $0.vertexB) < ($1.vertexA, $1.vertexB) }
        return result
    }

    private static func firstTriangleIsLeftFace(
        of edge: (lo: Int, hi: Int),
        triangle: MeshTriangle,
        weldedIndex: [Int]
    ) -> Bool {
        let welded = (weldedIndex[triangle.a], weldedIndex[triangle.b], weldedIndex[triangle.c])
        return switch edge {
        case (welded.0, welded.1), (welded.1, welded.2), (welded.2, welded.0): true
        default: false
        }
    }
}
