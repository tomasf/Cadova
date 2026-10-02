import Foundation

extension MeshOffset {
    /// Removes fins (two copies of a triangle facing opposite ways, enclosing nothing), then separates sheets that
    /// touch along an edge or at a vertex: around a shared edge, each triangle pairs with its neighbor across a wedge
    /// of solid, and each vertex gets one copy per fan of triangles connected through edges
    static func cleanedUp(_ contour: Contour) -> (vertices: [Vector3D], faces: [Face]) {
        var result = (vertices: contour.vertices, faces: contour.faces)
        // Separating one configuration can expose another, so repeat until every edge has two faces, and end on a
        // separation, which also splits the vertices cutting fans pinches
        for round in 0..<4 {
            result = separated(vertices: result.vertices, faces: result.faces)
            if round == 3 || VertexFans(faces: result.faces, vertexCount: result.vertices.count).irregularEdges(in: result.faces).isEmpty { break }
            result = cutLoopedFans(vertices: result.vertices, faces: result.faces)
        }
        // Whatever contouring couldn't close is closed here, so the result is always a solid
        if let closed = filledHoles(vertices: result.vertices, faces: result.faces) {
            result = separated(vertices: closed.vertices, faces: closed.faces)
        }
        return result
    }

    /// Closes holes: edges used more in one direction than the other, such as the rim of a hole, form loops, and a
    /// fan of triangles over each loop, facing the other way, balances them. The holes are gaps between cells where
    /// contouring couldn't connect the surface, a cell or two across, so the fans stay within the tolerance of it.
    /// Returns nil when there's nothing to close.
    static func filledHoles(vertices: [Vector3D], faces: [Face]) -> (vertices: [Vector3D], faces: [Face])? {
        // The excess of each edge, as directed edges to follow around loops. Found fan by fan rather than by hashing
        // every edge: nearly always there are none.
        let unbalanced = VertexFans(faces: faces, vertexCount: vertices.count).unbalancedEdges(in: faces)
        var outgoing: [Int: [Int]] = [:]
        var excess = 0
        for edge in unbalanced {
            for _ in 0..<edge.surplus { outgoing[edge.from, default: []].append(edge.to) }
            excess += edge.surplus
        }
        guard excess > 0 else { return nil }
        var vertices = vertices, faces = faces
        // Every vertex has as much excess leaving as arriving, so walking from one always leads back to it
        for start in outgoing.keys.sorted() {
            while let first = outgoing[start]?.popLast() {
                var loop = [start], current = first
                while current != start {
                    loop.append(current)
                    guard let next = outgoing[current]?.popLast() else { break }
                    current = next
                }
                guard current == start, loop.count >= 3 else { continue }
                let center = vertices.count
                vertices.append(loop.reduce(Vector3D.zero) { $0 + vertices[$1] } / Double(loop.count))
                for n in loop.indices {
                    faces.append((center, loop[(n + 1) % loop.count], loop[n]))
                }
            }
        }
        return (vertices, faces)
    }

    /// An edge still shared by four triangles after separating has an end whose fan loops through the other end
    /// twice. Cutting that fan at the edge leaves two arcs from the other end back to it; one of them gets its own
    /// copy of the vertex.
    static func cutLoopedFans(vertices: [Vector3D], faces: [Face]) -> (vertices: [Vector3D], faces: [Face]) {
        var vertices = vertices
        var faces = faces
        // Everything is decided on the faces as they are; renaming as we go would hide edges from later ones
        let original = faces
        let fans = VertexFans(faces: original, vertexCount: vertices.count)
        func corners(_ index: Int) -> [Int] { [original[index].0, original[index].1, original[index].2] }
        var touched = Set<Int>()
        for (a, b) in fans.irregularEdges(in: original) where fans.faces(around: a, with: b, in: original).count == 4 {
            for (v, w) in [(a, b), (b, a)] {
                guard !touched.contains(v), !touched.contains(w) else { break }
                // Group v's triangles through shared edges other than v-w
                let fan = Array(fans.members[fans.offsets[v]..<fans.offsets[v + 1]])
                var parent = Array(fan.indices)
                func root(_ x: Int) -> Int {
                    var x = x
                    while parent[x] != x { parent[x] = parent[parent[x]]; x = parent[x] }
                    return x
                }
                var slot: [Int: Int] = [:]
                for (n, face) in fan.enumerated() { slot[face] = n }
                for (n, face) in fan.enumerated() {
                    for u in corners(face) where u != v && u != w {
                        let shared = fans.faces(around: v, with: u, in: original)
                        guard shared.count == 2 else { continue }
                        let other = shared[0] == face ? shared[1] : shared[0]
                        if let m = slot[other] { parent[root(n)] = root(m) }
                    }
                }
                // Ordered by their first triangle, so which arc gets the copy doesn't change from run to run
                let arcs = Dictionary(grouping: fan.indices, by: root).values.map { $0.map { fan[$0] } }.sorted { $0[0] < $1[0] }
                guard arcs.count == 2 else { continue }
                // Each arc must hold one triangle of the edge each way
                let balanced = arcs.allSatisfy { arc in
                    let directed = arc.flatMap { index in
                        let c = corners(index)
                        return (0..<3).map { (c[$0], c[($0 + 1) % 3]) }
                    }
                    return directed.filter { $0 == (v, w) }.count == 1 && directed.filter { $0 == (w, v) }.count == 1
                }
                guard balanced else { continue }
                let copy = vertices.count
                vertices.append(vertices[v])
                for face in arcs[1] {
                    if faces[face].0 == v { faces[face].0 = copy }
                    if faces[face].1 == v { faces[face].1 = copy }
                    if faces[face].2 == v { faces[face].2 = copy }
                }
                touched.insert(v)
                touched.insert(w)
                break
            }
        }
        return (vertices, faces)
    }
}
