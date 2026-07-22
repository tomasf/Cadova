import Foundation
import Manifold3D

/// Merges vertices of `meshGL` that sit within `tolerance` of each other, dropping any triangle
/// that degenerates (two or more shared corners) as a result. Pure Swift position-matching —
/// deterministic regardless of how Manifold's own boolean union happened to resolve (or not
/// resolve) the same coincidence.
internal func weldingCoincidentVertices(_ meshGL: MeshGL, tolerance: Double = 1e-4) -> (vertices: [Vector3D], faces: [[Int]]) {
    let vertices = meshGL.vertices
    let triangles = meshGL.triangles

    var parent = Array(vertices.indices)
    func find(_ x: Int) -> Int {
        var x = x
        while parent[x] != x {
            parent[x] = parent[parent[x]]
            x = parent[x]
        }
        return x
    }
    func union(_ a: Int, _ b: Int) {
        let ra = find(a), rb = find(b)
        if ra != rb { parent[ra] = rb }
    }

    // Spatial hash so near-duplicate lookup stays roughly linear instead of O(n²).
    struct CellKey: Hashable { let x, y, z: Int64 }
    let cellSize = tolerance * 2
    func cell(_ v: Vector3D) -> CellKey {
        CellKey(x: Int64((v.x / cellSize).rounded(.down)), y: Int64((v.y / cellSize).rounded(.down)), z: Int64((v.z / cellSize).rounded(.down)))
    }
    var buckets: [CellKey: [Int]] = [:]
    for (i, v) in vertices.enumerated() {
        buckets[cell(v), default: []].append(i)
    }

    for (i, v) in vertices.enumerated() {
        let base = cell(v)
        for dx in -1...1 { for dy in -1...1 { for dz in -1...1 {
            let key = CellKey(x: base.x + Int64(dx), y: base.y + Int64(dy), z: base.z + Int64(dz))
            guard let candidates = buckets[key] else { continue }
            for j in candidates where j > i {
                if (vertices[j] - v).magnitude < tolerance {
                    union(i, j)
                }
            }
        }}}
    }

    var canonicalIndex: [Int: Int] = [:]
    var newVertices: [Vector3D] = []
    func canonical(_ i: Int) -> Int {
        let root = find(i)
        if let existing = canonicalIndex[root] { return existing }
        let newIndex = newVertices.count
        newVertices.append(vertices[root])
        canonicalIndex[root] = newIndex
        return newIndex
    }

    var newFaces: [[Int]] = []
    newFaces.reserveCapacity(triangles.count)
    for t in triangles {
        let a = canonical(Int(t.a)), b = canonical(Int(t.b)), c = canonical(Int(t.c))
        guard a != b, b != c, a != c else { continue }
        newFaces.append([a, b, c])
    }

    return (newVertices, newFaces)
}
