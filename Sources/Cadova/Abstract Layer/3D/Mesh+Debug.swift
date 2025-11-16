import Foundation

fileprivate struct EdgePair<V: Hashable>: Hashable {
    let a: V
    let b: V
    init(_ a: V, _ b: V) { self.a = a; self.b = b }
    var reversed: EdgePair<V> { EdgePair<V>(b, a) }
}

public extension Mesh {
    /// Analyzes the mesh for common structural issues directly on the mesh's source faces.
    ///
    /// This validation runs against `faces` and your `resolver`, checking for:
    /// - Duplicate vertices within a face (same `Vertex` key repeated)
    /// - Degenerate triangles (near-zero area when resolved to positions)
    /// - Inward-facing winding (negative signed volume)
    /// - Non-manifold edges (edges not shared by exactly two faces in opposite directions)
    ///
    /// > Important: This is a diagnostic helper; it does not attempt to repair or modify the mesh.
    ///
    /// - Returns: An array of `Mesh.Issue` values describing detected problems, or an empty array if none were found.
    ///
    func validate() -> [Issue] {
        var issues: [Issue] = []

        // 1) Per-face checks
        for (i, face) in faces.enumerated() {
            // Duplicate vertex keys within the face
            if Set(face).count != face.count {
                issues.append(.faceHasDuplicateVertices(faceIndex: i))
            }

            // Degenerate triangle (only when explicitly a triangle)
            if face.count == 3 {
                let a = lookup(face[0])
                let b = lookup(face[1])
                let c = lookup(face[2])
                let area = ((b - a) × (c - a)).magnitude
                if area < 1e-9 {
                    issues.append(.degenerateTriangle(faceIndex: i))
                }
            }
        }

        // 2) Orientation (signed volume) using source faces
        if signedVolumeFromSourceFaces() < 0 {
            issues.append(.insideOut)
        }

        // 3) Manifoldness check using vertex keys
        issues.append(contentsOf: checkManifoldEdgesFromSource())

        return issues
    }

    /// Signed volume computed directly from the source faces and resolver.
    private func signedVolumeFromSourceFaces() -> Double {
        // Fan-triangulate each polygonal face about its first vertex.
        var vol = 0.0
        for face in faces {
            guard face.count >= 3 else { continue }
            let p0 = lookup(face[0])
            for i in 1..<(face.count - 1) {
                let p1 = lookup(face[i])
                let p2 = lookup(face[i + 1])
                // Tetrahedron signed volume relative to origin
                vol += (p0 ⋅ (p1 × p2)) / 6.0
            }
        }
        return vol
    }

    /// Edge manifoldness check on source faces (by vertex key), requiring exactly two opposing directions.
    private func checkManifoldEdgesFromSource() -> [Issue] {
        var issues: [Issue] = []
        var edgeMap: [EdgePair<Vertex>: Int] = [:]

        for face in faces {
            for (a, b) in face.wrappedPairs() {
                edgeMap[EdgePair(a, b), default: 0] += 1
            }
        }

        for (edge, countAB) in edgeMap {
            let countBA = edgeMap[edge.reversed] ?? 0
            if countAB != 1 || countBA != 1 {
                issues.append(.nonManifoldEdge(a: edge.a, b: edge.b))
            }
        }
        return issues
    }

    enum Issue: CustomStringConvertible {
        case faceHasDuplicateVertices(faceIndex: Int)
        case degenerateTriangle(faceIndex: Int)
        case insideOut
        case nonManifoldEdge(a: Vertex, b: Vertex)

        public var description: String {
            switch self {
            case .faceHasDuplicateVertices(let i):
                return "Face \(i) has duplicate vertex keys."
            case .degenerateTriangle(let i):
                return "Face \(i) is a degenerate triangle (collinear or zero area)."
            case .insideOut:
                return "Mesh appears to be inside-out (negative volume). Check face winding."
            case .nonManifoldEdge(let a, let b):
                return "Edge (\(a), \(b)) is non-manifold (must be shared by exactly two faces in opposite directions)."
            }
        }
    }
}
