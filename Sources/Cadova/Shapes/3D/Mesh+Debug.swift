import Foundation

public extension Mesh {
    /// Generates a 3D visualization of the mesh for debugging purposes.
    ///
    /// This method constructs thin extrusions for each face in the mesh, allowing you to
    /// inspect face orientation, layout, and normals without requiring the mesh to be manifold.
    /// Inward-facing polygons (with incorrect winding) are visually distinguished by being colored pink.
    ///
    /// > Important: This is a heavy operation intended primarily for visual inspection during development.
    /// It performs a full projection and extrusion of every face individually and is not optimized for performance.
    /// Use only with relatively simple meshes or subsets of geometry.
    ///
    /// - Returns: A composite geometry consisting of extruded versions of each face in the mesh.
    @GeometryBuilder3D
    func visualizedForDebugging() -> any Geometry3D {
        for face in meshData.faces {
            visualizeFace(face.map { meshData.vertices[$0] })
        }
    }

    private func visualizeFace(_ faceVertices: [Vector3D]) -> any Geometry3D {
        let thickness = 0.005
        guard faceVertices.count >= 3 else { return Empty() }
        let v0 = faceVertices[0]
        let v1 = faceVertices[1]
        let v2 = faceVertices[2]
        let normal = ((v1 - v0) × (v2 - v0)).normalized

        let u = (v1 - v0).normalized
        let v = (normal × u).normalized
        let projected2D = faceVertices.map {
            Vector2D(x: ($0 - v0) ⋅ u, y: ($0 - v0) ⋅ v)
        }

        let polygon = Polygon(projected2D)
        let extruded = polygon.extruded(height: thickness)
            .colored(.lightPink)
            .adding {
                polygon.extruded(height: thickness)
                    .translated(z: thickness)
            }

        let rotation = AffineTransform3D([
            [u.x, v.x, normal.x, 0],
            [u.y, v.y, normal.y, 0],
            [u.z, v.z, normal.z, 0],
            [0, 0, 0, 1]
        ])
        return extruded.transformed(rotation.translated(v0))
    }
}

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
