import Foundation

public extension Mesh {
    /// Analyzes the mesh for common structural issues and returns a list of detected problems.
    ///
    /// This method performs a comprehensive validation of the mesh geometry, checking for:
    /// - Duplicate vertex indices within faces
    /// - References to out-of-bounds vertex indices
    /// - Degenerate triangles (with near-zero area)
    /// - Vertices that are not referenced by any face
    /// - Inward-facing winding (negative signed volume)
    /// - Non-manifold edges (edges not shared by exactly two faces in opposite directions)
    ///
    /// > Important: This method is intended for debugging and validation purposes. It does not attempt to repair or modify the mesh.
    ///
    /// - Returns: An array of `Mesh.Issue` values representing detected problems, or an empty array if the mesh passes all checks.
    ///
    func validate() -> [Issue] {
        var issues: [Issue] = []
        var usedVertices = Set<Int>()

        for (i, face) in meshData.faces.enumerated() {
            if Set(face).count != face.count {
                issues.append(.faceHasDuplicateIndices(faceIndex: i))
            }

            for index in face {
                if index < 0 || index >= meshData.vertices.count {
                    issues.append(.faceOutOfBoundsIndex(faceIndex: i, invalidIndex: index))
                } else {
                    usedVertices.insert(index)
                }
            }

            if face.count == 3 {
                let a = meshData.vertices[face[0]]
                let b = meshData.vertices[face[1]]
                let c = meshData.vertices[face[2]]
                let area = ((b - a) × (c - a)).magnitude
                if area < 1e-9 {
                    issues.append(.degenerateTriangle(faceIndex: i))
                }
            }
        }

        for i in 0..<meshData.vertices.count {
            if usedVertices.contains(i) == false {
                issues.append(.unusedVertex(index: i))
            }
        }

        if meshData.signedVolume < 0 {
            issues.append(.insideOut)
        }

        issues.append(contentsOf: checkManifoldEdges())

        return issues
    }

    private func checkManifoldEdges() -> [Issue] {
        var issues: [Issue] = []

        struct IndexPair: Hashable {
            let a: Int
            let b: Int

            init(_ a: Int, _ b: Int) {
                self.a = a
                self.b = b
            }

            var reversed: IndexPair {
                IndexPair(b, a)
            }
        }

        var edgeMap: [IndexPair: Int] = [:]
        for face in meshData.faces {
            for (a, b) in face.wrappedPairs() {
                edgeMap[IndexPair(a, b), default: 0] += 1
            }
        }

        for (indexPair, count) in edgeMap {
            let oppositeCount = edgeMap[indexPair.reversed] ?? 0
            if count != 1 || oppositeCount != 1 {
                issues.append(.nonManifoldEdge(edge: [indexPair.a, indexPair.b]))
            }
        }

        return issues
    }

    enum Issue: CustomStringConvertible {
        case faceHasDuplicateIndices(faceIndex: Int)
        case faceOutOfBoundsIndex(faceIndex: Int, invalidIndex: Int)
        case degenerateTriangle(faceIndex: Int)
        case unusedVertex(index: Int)
        case insideOut
        case nonManifoldEdge(edge: [Int])

        public var description: String {
            switch self {
            case .faceHasDuplicateIndices(let i):
                return "Face \(i) has duplicate vertex indices."
            case .faceOutOfBoundsIndex(let i, let idx):
                return "Face \(i) contains invalid vertex index \(idx)."
            case .degenerateTriangle(let i):
                return "Face \(i) is a degenerate triangle (collinear or zero area)."
            case .unusedVertex(let i):
                return "Vertex \(i) is not used by any face."
            case .insideOut:
                return "Mesh appears to be inside-out (negative volume). Check face winding."
            case .nonManifoldEdge(let edge):
                return "Edge \(edge) is non-manifold (must be shared by exactly two faces in opposite directions)."
            }
        }
    }
}
