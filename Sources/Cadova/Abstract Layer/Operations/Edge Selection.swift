import Foundation
import Manifold3D

public struct Edge: Sendable, Hashable {
    public let segments: [Segment]

    public struct Segment: Sendable, Hashable {
        public let a: Vector3D
        public let b: Vector3D
    }
}

public struct EdgeCriteria: Sendable {
    public init() {}

    public var withinBox: BoundingBox3D? // entire edge within box
    public var startsWithin: BoundingBox3D?
    /// `direction`: the desired orientation of the **first** edge segment, plus an angular tolerance.
    /// `maxDeviation`: optional maximum angle (in degrees) that subsequent segments may deviate from
    /// the first segment’s direction. Leave `maxDeviation` `nil` to disable the deviation filter.
    public var direction: (vector: Direction3D, tolerance: Angle)? // first segment must point this direction, within the tolerance
    public var maxDeviation: Angle?
    public var isClosedLoop: Bool? // If set, requires the edge to be a closed loop (or to NOT be).
    public var canIntersect: Bool = true // can the edge cross itself. that is, can a vertex be used more than once? default true?
    public var minimumLength: Double?
    public var maximumLength: Double?
    public var minAngle: Angle? // positive angles mean the faces for an edge segment must be convex; an external angle. negative angles = internal, concave angle.
    public var maxAngle: Angle?
}

internal struct EdgePair: Sendable, Hashable {
    let a: Int
    let b: Int

    init(a: Int, b: Int) {
        self.a = min(a, b)
        self.b = max(a, b)
    }
}

internal struct IndexSegment: Hashable {
    let a: Int
    let b: Int
}

// Memo table: shortest length seen for (vertex, seedEdge)
struct PathKey: Hashable {
    let vertex: Int
    let seed  : EdgePair
}

public extension Geometry3D {
    func selectEdges(_ criteria: EdgeCriteria, @GeometryBuilder3D reader: @escaping @Sendable (any Geometry3D, [Edge]) -> (any Geometry3D)) -> any Geometry3D {
        readingConcrete { concrete, result in
            let vertices: [Vector3D]
            let triangles: [Manifold3D.Triangle] // Triangle has a,b,c indices from `vertices`
            (vertices, triangles) = concrete.readMesh()

            print(vertices.count, "vertices,", triangles.count, "triangles")


            // Build an adjacency list
            var adjacency = [Int: [Int]]()
            for tri in triangles {
                let indices = [tri.a, tri.b, tri.c]
                for i in 0..<3 {
                    let a = indices[i]
                    let b = indices[(i+1)%3]
                    adjacency[a, default: []].append(b)
                    adjacency[b, default: []].append(a)
                }
            }

            // Pre‑compute a unit direction vector for every undirected edge
            var edgeUnit = [EdgePair: Vector3D]()
            for (a, nbrs) in adjacency {
                for b in nbrs {
                    let pair = EdgePair(a: a, b: b)
                    if edgeUnit[pair] == nil {            // undirected – store once
                        edgeUnit[pair] = (vertices[b] - vertices[a]).normalized
                    }
                }
            }

            // If direction criterion present, pre‑compute cosine thresholds
            var desiredUnit: Vector3D = .zero
            var cosDirTol: Double = 1.0
            if let dirCrit = criteria.direction {
                desiredUnit = dirCrit.vector.unitVector
                cosDirTol   = cos(dirCrit.tolerance.radians)
            }
            let cosMaxDev: Double? = criteria.maxDeviation.map { cos($0.radians) }

            // Build triangle normals and map each undirected edge to the triangles that share it
            var edgeToTriangles = [EdgePair: [Int]]()
            var triNormals = [Vector3D](repeating: .zero, count: triangles.count)

            for (tIndex, tri) in triangles.enumerated() {
                let v0 = vertices[tri.a]
                let v1 = vertices[tri.b]
                let v2 = vertices[tri.c]
                triNormals[tIndex] = (v1 - v0) × (v2 - v0)  // not normalised yet

                let edgesForTri = [
                    EdgePair(a: tri.a, b: tri.b),
                    EdgePair(a: tri.b, b: tri.c),
                    EdgePair(a: tri.c, b: tri.a)
                ]
                for e in edgesForTri {
                    edgeToTriangles[e, default: []].append(tIndex)
                }
            }

            // Pre‑compute signed dihedral angles for edges that have two adjacent faces
            var dihedralAngle = [EdgePair: Angle]()
            for (edge, tris) in edgeToTriangles where tris.count == 2 {
                let n1 = triNormals[tris[0]].normalized
                let n2 = triNormals[tris[1]].normalized
                let dot = max(-1.0, min(1.0, n1 ⋅ n2))
                var angle: Angle = acos(dot) // magnitude in [0, π]

                // Determine sign: convex (external) is +, concave (internal) is –
                let edgeVec = (vertices[edge.b] - vertices[edge.a]).normalized
                let signVal = ((n1 × n2) ⋅ edgeVec)
                if signVal < 0 {
                    angle = -angle
                }
                dihedralAngle[edge] = angle   // signed angle in (‑π … π)
            }

            // ── Prune flat edges (dihedral ≈ 0°) from the adjacency list ──────────────
            /// Edges whose dihedral angle is below this threshold are considered flat and pruned.
            /// 0.001 rad ≈ 0.057°
            let flatEpsilon: Double = 1e-4
            var prunedAdjacency = [Int: [Int]]()
            for (v, nbrs) in adjacency {
                prunedAdjacency[v] = nbrs.filter { n in
                    if let flat = dihedralAngle[EdgePair(a: v, b: n)] {
                        return Swift.abs(flat.radians) >= flatEpsilon
                    } else {
                        // boundary edge (only one face) — keep it
                        return true
                    }
                }
            }
            print("adjacency", adjacency.count)
            adjacency = prunedAdjacency
            print("pruned adjacency", adjacency.count)

            // Helper utilities
            func angleBetween(_ u: Vector3D, _ v: Vector3D) -> Angle {
                acos(max(-1.0, min(1.0, u.normalized ⋅ v.normalized)))
            }

            @Sendable func edgeLength(_ segments: [IndexSegment]) -> Double {
                segments.reduce(0.0) { $0 + (vertices[$1.b] - vertices[$1.a]).magnitude }
            }

            func chainDirection(_ segments: [IndexSegment]) -> Direction3D {
                Direction3D(vertices[segments[0].b] - vertices[segments[0].a])
            }

            @Sendable func within(_ segments: [IndexSegment], box: BoundingBox3D) -> Bool {
                segments.allSatisfy { box.contains(vertices[$0.a]) && box.contains(vertices[$0.b]) }
            }


            // ── Parallelise seeds ────────────────────────────────────────────────────
            let adjConst         = adjacency                 // [Int:[Int]]
            let edgeUnitConst    = edgeUnit                  // [EdgePair:Vector3D]
            let dihedralConst    = dihedralAngle             // [EdgePair:Angle]
            let verticesConst    = vertices                  // [Vector3D]
            let criteriaConst    = criteria                  // EdgeCriteria (Sendable)
            let desiredUnitConst = desiredUnit               // Vector3D
            let cosDirTolConst   = cosDirTol                 // Double
            let cosMaxDevConst   = cosMaxDev                 // Double?

            let allEdges = await withTaskGroup(of: [Edge].self) { group in
                for (v, neighbours) in adjacency {
                    for n in neighbours {
                        group.addTask { @Sendable [adjConst,
                                                   edgeUnitConst,
                                                   dihedralConst,
                                                   verticesConst,
                                                   criteriaConst,
                                                   desiredUnitConst,
                                                   cosDirTolConst,
                                                   cosMaxDevConst,
                                                   v, n] in
                            // Each task gets its own visited set and result array
                            var localVisited = Set<EdgePair>()
                            var localEdges: [Edge] = []


                            var bestLen = [PathKey: Double]()

                            // Pre‑filter: seed must satisfy direction tolerance
                            if let _ = criteriaConst.direction {
                                let seedUnit = edgeUnitConst[EdgePair(a: v, b: n)]!
                                if desiredUnitConst ⋅ seedUnit < cosDirTolConst {
                                    return localEdges
                                }
                            }

                            let pair = EdgePair(a: v, b: n)
                            guard !localVisited.contains(pair) else { return localEdges }
                            localVisited.insert(pair)

                            var best: [IndexSegment] = []

                            func dfs(current: Int, previous: Int, chain: inout [IndexSegment], used: inout Set<Int>) {
                                // ── Memoisation ───────────────────────────────
                                let seedPair = EdgePair(a: chain[0].a, b: chain[0].b)
                                let state    = PathKey(vertex: current, seed: seedPair)
                                let currentLen = edgeLength(chain)
                                if let prevLen = bestLen[state], prevLen <= currentLen {
                                    return      // already reached this state with ≤ length
                                }
                                bestLen[state] = currentLen

                                if chain.count > verticesConst.count { return }

                                if chain.count > best.count { best = chain }

                                if let maxLen = criteriaConst.maximumLength,
                                   edgeLength(chain) > maxLen { return }

                                guard let neighbors = adjConst[current] else { return }

                                for next in neighbors {
                                    if next == previous { continue }
                                    if !criteriaConst.canIntersect && used.contains(next) { continue }
                                    if criteriaConst.canIntersect, used.contains(next) {
                                        if next == chain.first!.a {
                                            let loop = chain + [IndexSegment(a: current, b: next)]
                                            best = loop.count > best.count ? loop : best
                                        }
                                        continue
                                    }

                                    let segment = IndexSegment(a: current, b: next)

                                    // Direction tolerance (optional) and maxDeviation (always, if set)
                                    let firstUnit = edgeUnitConst[EdgePair(a: chain[0].a, b: chain[0].b)]!

                                    // If a start‑direction was provided, check the *first* edge once.
                                    if chain.count == 1, let _ = criteriaConst.direction {
                                        if desiredUnitConst ⋅ firstUnit < cosDirTolConst { return }
                                    }

                                    // Always enforce maxDeviation when it exists.
                                    if let cosMax = cosMaxDevConst {
                                        let segUnit = edgeUnitConst[EdgePair(a: segment.a, b: segment.b)]!
                                        if firstUnit ⋅ segUnit < cosMax { continue }
                                    }

                                    // Face-angle constraints
                                    if let minA = criteriaConst.minAngle, let maxA = criteriaConst.maxAngle {
                                        let edgeKey = EdgePair(a: current, b: next)
                                        guard let faceAngle = dihedralConst[edgeKey] else { continue }
                                        if faceAngle < minA || faceAngle > maxA { continue }
                                    }

                                    // Length after adding this segment
                                    let newLen = edgeLength(chain) +
                                    (verticesConst[segment.b] - verticesConst[segment.a]).magnitude
                                    if let maxLen = criteriaConst.maximumLength, newLen > maxLen { continue }

                                    chain.append(segment)
                                    used.insert(next)
                                    dfs(current: next, previous: current, chain: &chain, used: &used)
                                    chain.removeLast()
                                    used.remove(next)
                                }
                            }

                            var chain: [IndexSegment] = [IndexSegment(a: v, b: n)]
                            var used: Set<Int> = [v, n]
                            dfs(current: n, previous: v, chain: &chain, used: &used)

                            // Validate & convert
                            if !best.isEmpty {
                                if let box = criteriaConst.withinBox, !within(best, box: box) { }
                                else if let startBox = criteriaConst.startsWithin,
                                        !startBox.contains(verticesConst[best.first!.a]) { }
                                else {
                                    let len = edgeLength(best)
                                    if let minLen = criteriaConst.minimumLength, len < minLen { }
                                    else if let maxLen = criteriaConst.maximumLength, len > maxLen { }
                                    else if let closed = criteriaConst.isClosedLoop,
                                            closed != (best.first!.a == best.last!.b) { }
                                    else {
                                        let segs = best.map { Edge.Segment(a: verticesConst[$0.a], b: verticesConst[$0.b]) }
                                        localEdges.append(Edge(segments: segs))
                                    }
                                }
                            }
                            return localEdges
                        }
                    }
                }

                // Merge task results
                return await group.reduce(into: []) { $0 += $1 }
            }

            // Deduplicate identical edges that may have been found in parallel
            let uniqueEdges = Array(Set(allEdges))

            return reader(self, uniqueEdges)
        }
    }
}
