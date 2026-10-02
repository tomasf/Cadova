import Foundation

extension OffsetCorners {
    /// Works out the pieces for one offset, stage by stage. The stages share what they find about the mesh: which
    /// faces each edge joins, which edges are convex, the corners, and the sharp edges meeting at each vertex.
    struct PieceBuilder {
        let field: MeshDistanceField
        let r: Double
        let sign: Double
        let style: LineJoinStyle
        let limit: Double
        let tolerance: Double
        let vertices: [Vector3D]
        let faceCount: Int
        /// Normals toward the side the offset grows into
        let n: [Vector3D]
        /// Faces whose normals sharp joins can rely on. Besides the faces the distance field distrusts, that leaves
        /// out faces narrower than the tolerance: their corners may each lie the tolerance off, as where an earlier
        /// offset's contouring lays a sliver along a crease, and their normals can then point anywhere. A miter built
        /// on such a normal juts out as a spike.
        let trusted: [Bool]

        var faceOfDirected: [UInt64: Int] = [:]
        var fan: [[Int]]
        var concave = Set<UInt64>()
        var convexEdges: [(a: Int, b: Int, faceA: Int, faceB: Int)] = []
        var cornersOf: [Corner]
        /// Corners are cut by every cut of the edges meeting there, so a corner and the edges running into it agree
        var cutsAt: [[Cut]]
        /// The kept edges at each vertex: their faces, and their directions away from it
        var wedgeFacesAt: [[Int]]
        var wedgeDirectionsAt: [[Vector3D]]
        /// Sharp edges continuing each other through a vertex, as the index of the other edge, or -1
        var continuationAt: [[Int]]

        init(field: MeshDistanceField, r: Double, sign: Double, style: LineJoinStyle, limit: Double, tolerance: Double) {
            self.field = field
            self.r = r
            self.sign = sign
            self.style = style
            self.limit = limit
            self.tolerance = tolerance
            vertices = field.vertices
            faceCount = field.faceCount
            n = (0..<faceCount).map { field.faceNormal($0) * sign }
            trusted = (0..<faceCount).map { index in
                guard !field.isSuspect(index) else { return false }
                let f = field.face(index)
                let a = field.vertices[f.0], b = field.vertices[f.1], c = field.vertices[f.2]
                let longest = max((b - a).magnitude, (c - b).magnitude, (a - c).magnitude)
                return longest > 0 && ((b - a) × (c - a)).magnitude / longest >= tolerance
            }
            fan = [[Int]](repeating: [], count: vertices.count)
            cornersOf = [Corner](repeating: Corner(), count: vertices.count)
            cutsAt = [[Cut]](repeating: [], count: vertices.count)
            wedgeFacesAt = [[Int]](repeating: [], count: vertices.count)
            wedgeDirectionsAt = [[Vector3D]](repeating: [], count: vertices.count)
            continuationAt = [[Int]](repeating: [], count: vertices.count)
        }

        mutating func build() -> (grown: [Piece], removed: [Piece]) {
            mapEdges()
            classifyEdges()
            findCorners()
            gatherEdgeEnds()
            pairContinuations()
            findJoints()
            let edges = edgePieces()
            let corners = cornerPieces()
            return (edges.grown + corners.grown, edges.removed + corners.removed)
        }

        func corners(_ face: Int) -> [Int] { let f = field.face(face); return [f.0, f.1, f.2] }
        func directedKey(_ a: Int, _ b: Int) -> UInt64 { UInt64(a) << 32 | UInt64(b) }
        func opposite(_ face: Int, _ a: Int, _ b: Int) -> Int { corners(face).first { $0 != a && $0 != b } ?? a }

        /// Which face uses each directed edge, and the faces around each vertex
        mutating func mapEdges() {
            for face in 0..<faceCount {
                let c = corners(face)
                for k in 0..<3 {
                    faceOfDirected[directedKey(c[k], c[(k + 1) % 3])] = face
                    fan[c[k]].append(face)
                }
            }
        }

        /// Edge convexity toward the offset
        mutating func classifyEdges() {
            for face in 0..<faceCount {
                let c = corners(face)
                for k in 0..<3 {
                    let a = c[k], b = c[(k + 1) % 3]
                    guard a < b, let other = faceOfDirected[directedKey(b, a)] else { continue }
                    let side = n[face] ⋅ (vertices[opposite(other, a, b)] - vertices[a])
                    let scale = 1e-9 * (vertices[b] - vertices[a]).magnitude
                    if side > scale { concave.insert(MeshDistanceField.edgeKey(a, b)) }
                    if side < -scale && trusted[face] && trusted[other] { convexEdges.append((a, b, face, other)) }
                }
            }
        }

        /// Each edge's cut (square, miter past the limit, bevel), and whether the edge is sharp enough to keep
        func edgeCut(_ na: Vector3D, _ nb: Vector3D) -> (kept: Bool, cut: Cut?) {
            let halfAngle = Foundation.acos(min(max(na ⋅ nb, -1), 1)) / 2
            let bisector = (na + nb).safelyNormalized
            switch style {
            case .bevel:
                return (r * (1 - cos(halfAngle)) >= tolerance, Cut(normal: bisector, at: r * cos(halfAngle)))
            case .square:
                return (r * (1 / cos(halfAngle) - 1) >= tolerance, Cut(normal: bisector, at: r))
            default:
                let exceeds = r / cos(halfAngle) > limit * r
                return (r * (1 / cos(halfAngle) - 1) >= tolerance, exceeds ? Cut(normal: bisector, at: r) : nil)
            }
        }

        /// Finishes a corner from its ring of faces: its axis, how wide its faces spread, and where it's cut
        func finish(_ corner: inout Corner) {
            // Averaged over distinct planes: a face split into several triangles mustn't pull the axis its way
            var distinct: [Vector3D] = []
            for f in corner.ring where !distinct.contains(where: { $0 ⋅ n[f] > 1 - 1e-9 }) { distinct.append(n[f]) }
            corner.axis = distinct.reduce(Vector3D.zero, +).safelyNormalized
            // Fewer than three distinct planes make no cone, only a flat fan with coincident sides
            guard distinct.count >= 3 else { return }
            var matrix = (0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
            for d in distinct {
                matrix.0 += d.x * d.x; matrix.1 += d.x * d.y; matrix.2 += d.x * d.z
                matrix.3 += d.y * d.y; matrix.4 += d.y * d.z; matrix.5 += d.z * d.z
            }
            let eigen = PlaneFit.eigenDecomposition(matrix)
            let flattest = eigen.vector((0..<3).min { eigen.value($0) < eigen.value($1) }!)
            corner.spread = distinct.map { abs($0 ⋅ flattest) }.max() ?? 0
            corner.widest = min(corner.ring.map { Foundation.acos(min(max(n[$0] ⋅ corner.axis, -1), 1)) }.max() ?? 0, 1.5)
            corner.usable = true
            let apex = r / cos(corner.widest)
            switch style {
            case .square: corner.cut = r
            case .miter: corner.cut = apex > limit * r ? r : nil
            case .bevel: corner.cut = r * (corner.ring.map { corner.axis ⋅ n[$0] }.min() ?? 1)
            case .round: break
            }
        }

        /// Corners: convex vertices (no concave edge around them), with all their faces in ring order
        mutating func findCorners() {
            for v in vertices.indices where fan[v].count >= 3 {
                var corner = Corner()
                var face = fan[v][0]
                var closed = false
                for _ in 0...fan[v].count {
                    corner.ring.append(face)
                    let c = corners(face)
                    let k = c.firstIndex(of: v)!
                    guard let next = faceOfDirected[directedKey(v, c[(k + 2) % 3])] else { break }
                    if next == fan[v][0] { closed = true; break }
                    face = next
                }
                guard closed, corner.ring.count == fan[v].count else { continue }
                var anyConcave = false, defective = false
                for f in corner.ring {
                    if !trusted[f] { defective = true }
                    let c = corners(f)
                    for k in 0..<3 where c[k] == v || c[(k + 1) % 3] == v {
                        if concave.contains(MeshDistanceField.edgeKey(c[k], c[(k + 1) % 3])) { anyConcave = true }
                    }
                }
                guard !anyConcave, !defective else { continue }
                finish(&corner)
                cornersOf[v] = corner
            }
        }

        /// Each kept sharp edge's cut, faces and direction, at both its ends
        mutating func gatherEdgeEnds() {
            for edge in convexEdges {
                let (kept, cut) = edgeCut(n[edge.faceA], n[edge.faceB])
                guard kept else { continue }
                for (end, other) in [(edge.a, edge.b), (edge.b, edge.a)] {
                    if let cut { cutsAt[end].append(cut) }
                    wedgeDirectionsAt[end].append((vertices[other] - vertices[end]).safelyNormalized)
                    for f in [edge.faceA, edge.faceB] where !wedgeFacesAt[end].contains(f) { wedgeFacesAt[end].append(f) }
                }
            }
        }

        /// Sharp edges continuing each other through a vertex, paired straightest first
        mutating func pairContinuations() {
            for v in vertices.indices where !wedgeDirectionsAt[v].isEmpty {
                let directions = wedgeDirectionsAt[v]
                var continuation = [Int](repeating: -1, count: directions.count)
                var pairs: [(Double, Int, Int)] = []
                for i in directions.indices {
                    for j in (i + 1)..<directions.count where directions[i] ⋅ directions[j] < -0.5 {
                        pairs.append((directions[i] ⋅ directions[j], i, j))
                    }
                }
                for (_, i, j) in pairs.sorted(by: { $0.0 < $1.0 }) where continuation[i] < 0 && continuation[j] < 0 {
                    continuation[i] = j
                    continuation[j] = i
                }
                continuationAt[v] = continuation
            }
        }

        /// Joints: where a chain of sharp edges bends, two wedges continue nearly straight through a vertex that isn't a
        /// corner. Their ends leave a gap on the outside of the bend, which a cap over the wedges' faces fills.
        /// Elsewhere, such as a saddle where edges meet at an angle, the edges' own regions already overlap.
        mutating func findJoints() {
            for v in vertices.indices where !cornersOf[v].usable && wedgeDirectionsAt[v].count == 2 {
                guard wedgeDirectionsAt[v][0] ⋅ wedgeDirectionsAt[v][1] <= -0.5 else { continue }
                var joint = Corner()
                // Ordered by angle around the faces' mean normal, so consecutive normals bound their cone
                let mean = wedgeFacesAt[v].reduce(Vector3D.zero) { $0 + n[$1] }.safelyNormalized
                let first = n[wedgeFacesAt[v][0]]
                let off = first - mean * (first ⋅ mean)
                guard off.magnitude > 1e-9 else { continue }
                let reference = off.safelyNormalized
                let side = mean × reference
                joint.ring = wedgeFacesAt[v].sorted {
                    Foundation.atan2(n[$0] ⋅ side, n[$0] ⋅ reference) < Foundation.atan2(n[$1] ⋅ side, n[$1] ⋅ reference)
                }
                finish(&joint)
                guard joint.usable else { continue }
                joint.isJoint = true
                cornersOf[v] = joint
            }
        }
    }
}
