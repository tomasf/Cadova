import Foundation
import Manifold3D

/// A chain of connected sharp edge segments, along with the welded vertex indices of its endpoints.
/// The vertex indices allow junction bookkeeping (multiple chains meeting at a vertex) downstream.
internal struct EdgeChain {
    let foundEdge: FoundEdge
    let startVertexIndex: Int
    let endVertexIndex: Int
}

/// The complete result of edge extraction from a mesh.
internal struct ExtractedEdgeSet {
    let chains: [EdgeChain]
    /// The number of sharp mesh edges incident to each welded vertex index.
    /// Vertices of degree 3 or more are junctions.
    let sharpEdgeDegrees: [Int: Int]
}

/// Extracts sharp edges from a manifold mesh, grouping connected segments into chains.
internal enum EdgeExtractor {
    // Local typealias to avoid confusion with Cadova.Triangle (the geometric type)
    private typealias MeshTriangle = Manifold3D.Triangle

    /// - Parameter maskManifolds: The evaluated geometry of each of `query`'s mask constraints, in
    ///   the same order. Pass an empty array when the query has no mask constraints.
    static func edges(in manifold: Manifold, matching query: EdgeQuery, maskManifolds: [Manifold] = []) -> [FoundEdge] {
        let candidates = chains(
            in: manifold,
            minimumSharpness: query.minimumSharpness,
            maximumSharpness: query.maximumSharpness,
            maximumTurnAngle: query.maximumTurnAngle
        )
        .chains.map(\.foundEdge)

        guard !maskManifolds.isEmpty else {
            return candidates.filter { query.matches($0) }
        }

        // Containment is memoized per distinct vertex position rather than per (edge, vertex)
        // pair, since junction vertices are shared across multiple chains.
        let allVertices = candidates.flatMap(\.vertices)
        let containmentLookups = maskManifolds.map { maskContainment(of: allVertices, in: $0) }
        return candidates.filter { query.matches($0, maskContainment: containmentLookups) }
    }

    // MARK: - Mask containment

    /// Maps each distinct vertex position to whether it lies inside `manifold`, treated as a solid.
    private static func maskContainment(of vertices: [Vector3D], in manifold: Manifold) -> [Vector3D: Bool] {
        var result: [Vector3D: Bool] = [:]
        for vertex in vertices where result[vertex] == nil {
            result[vertex] = contains(vertex, in: manifold)
        }
        return result
    }

    /// A point-in-solid test via ray-cast parity: an odd number of surface crossings between the
    /// point and a point known to be outside the manifold means the point is inside.
    ///
    /// Ray-casting is BVH-accelerated (the same primitive `readingSurfaces` uses), so this is cheap
    /// once per distinct point; the escape direction is an arbitrary skewed vector, chosen to make
    /// the ray graze along a mesh face or edge unlikely.
    private static let escapeDirection = Direction3D(x: 0.5231, y: 0.6180, z: 0.5878)

    private static func contains(_ point: Vector3D, in manifold: Manifold) -> Bool {
        guard !manifold.isEmpty else { return false }
        let bounds = BoundingBox3D(manifold.bounds)
        guard bounds.contains(point) else { return false }
        let segment = bounds.coveringSegment(from: point, in: escapeDirection)
        let hits = manifold.rayCast(from: segment.start, to: segment.end)
        return hits.count % 2 == 1
    }

    static func chains(
        in manifold: Manifold,
        minimumSharpness: Angle,
        maximumSharpness: Angle? = nil,
        maximumTurnAngle: Angle
    ) -> ExtractedEdgeSet {
        let mesh = manifold.meshGL()
        let vertices = mesh.vertices
        let triangles = mesh.triangles
        guard !triangles.isEmpty else { return ExtractedEdgeSet(chains: [], sharpEdgeDegrees: [:]) }

        let weldedIndex = weldVertices(vertices)
        let normals = triangleNormals(vertices: vertices, triangles: triangles)
        let adjacency = buildAdjacency(triangles: triangles, weldedIndex: weldedIndex)
        let sharpEdges = findSharpEdges(
            vertices: vertices,
            triangles: triangles,
            normals: normals,
            weldedIndex: weldedIndex,
            adjacency: adjacency,
            threshold: minimumSharpness,
            maximumThreshold: maximumSharpness
        )
        let vertexToEdges = buildVertexToEdgesMap(sharpEdges: sharpEdges)
        let chains = buildAllChains(
            sharpEdges: sharpEdges, vertexToEdges: vertexToEdges, vertices: vertices,
            maximumTurnAngle: maximumTurnAngle
        )

        return ExtractedEdgeSet(chains: chains, sharpEdgeDegrees: vertexToEdges.mapValues(\.count))
    }

    // MARK: - Welding

    /// Maps each vertex index to a canonical index, merging vertices at identical positions.
    /// Meshes can contain duplicate vertices (e.g. from property boundaries); without welding,
    /// edges between them would appear to border only one triangle and be missed.
    private static func weldVertices(_ vertices: [Vector3D]) -> [Int] {
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

    // MARK: - Adjacency

    /// Encodes a canonical undirected edge (lo ≤ hi) into a single Int64 for dictionary keying.
    private static func edgeKey(_ a: Int, _ b: Int) -> Int64 {
        let lo = Int32(min(a, b))
        let hi = Int32(max(a, b))
        return (Int64(hi) << 32) | Int64(UInt32(bitPattern: lo))
    }

    private struct AdjacentTriangles {
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

    private static func buildAdjacency(triangles: [MeshTriangle], weldedIndex: [Int]) -> [Int64: AdjacentTriangles] {
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

    private static func triangleNormals(vertices: [Vector3D], triangles: [MeshTriangle]) -> [Vector3D?] {
        triangles.map { triangle in
            let v0 = vertices[triangle.a]
            let normal = (vertices[triangle.b] - v0) × (vertices[triangle.c] - v0)
            return normal.magnitude > 1e-12 ? normal.normalized : nil
        }
    }

    // MARK: - Sharp edge detection

    private struct SharpEdge {
        let vertexA: Int              // welded start vertex index
        let vertexB: Int              // welded end vertex index
        let normalLeft: Direction3D   // outward normal of the left face when traveling A→B
        let normalRight: Direction3D  // outward normal of the right face when traveling A→B
        let isConvex: Bool
    }

    private static func findSharpEdges(
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

    // MARK: - Chain construction

    private struct EdgeReference {
        let edgeIndex: Int
        let reversed: Bool  // true when this edge is entered via vertexB (traveling B→A)
    }

    private static func buildVertexToEdgesMap(sharpEdges: [SharpEdge]) -> [Int: [EdgeReference]] {
        var map: [Int: [EdgeReference]] = [:]
        map.reserveCapacity(sharpEdges.count)

        for (index, edge) in sharpEdges.enumerated() {
            map[edge.vertexA, default: []].append(EdgeReference(edgeIndex: index, reversed: false))
            map[edge.vertexB, default: []].append(EdgeReference(edgeIndex: index, reversed: true))
        }

        return map
    }

    private static func buildAllChains(
        sharpEdges: [SharpEdge],
        vertexToEdges: [Int: [EdgeReference]],
        vertices: [Vector3D],
        maximumTurnAngle: Angle
    ) -> [EdgeChain] {
        var visited = [Bool](repeating: false, count: sharpEdges.count)

        return sharpEdges.indices.compactMap { startIndex in
            guard !visited[startIndex] else { return nil }
            return buildChain(
                startIndex: startIndex,
                sharpEdges: sharpEdges,
                vertexToEdges: vertexToEdges,
                vertices: vertices,
                maximumTurnAngle: maximumTurnAngle,
                visited: &visited
            )
        }
    }

    /// Builds the complete chain containing the given starting edge by walking outward in both
    /// directions until hitting a junction, a convexity change, a sharp turn, or a dead end.
    private static func buildChain(
        startIndex: Int,
        sharpEdges: [SharpEdge],
        vertexToEdges: [Int: [EdgeReference]],
        vertices: [Vector3D],
        maximumTurnAngle: Angle,
        visited: inout [Bool]
    ) -> EdgeChain {
        let startEdge = sharpEdges[startIndex]
        visited[startIndex] = true

        let forward = walk(
            fromVertex: startEdge.vertexB,
            direction: vertices[startEdge.vertexB] - vertices[startEdge.vertexA],
            convex: startEdge.isConvex,
            sharpEdges: sharpEdges, vertexToEdges: vertexToEdges, vertices: vertices,
            maximumTurnAngle: maximumTurnAngle,
            visited: &visited
        )
        let backward = walk(
            fromVertex: startEdge.vertexA,
            direction: vertices[startEdge.vertexA] - vertices[startEdge.vertexB],
            convex: startEdge.isConvex,
            sharpEdges: sharpEdges, vertexToEdges: vertexToEdges, vertices: vertices,
            maximumTurnAngle: maximumTurnAngle,
            visited: &visited
        )

        let orderedEdges = backward.steps.reversed().map { (edgeIndex: $0.edgeIndex, reversed: !$0.reversed) }
            + [(edgeIndex: startIndex, reversed: false)]
            + forward.steps

        let segments = orderedEdges.map { step in
            let edge = sharpEdges[step.edgeIndex]
            return if step.reversed {
                EdgeSegment(
                    start: vertices[edge.vertexB],
                    end: vertices[edge.vertexA],
                    leftFaceNormal: edge.normalRight,
                    rightFaceNormal: edge.normalLeft
                )
            } else {
                EdgeSegment(
                    start: vertices[edge.vertexA],
                    end: vertices[edge.vertexB],
                    leftFaceNormal: edge.normalLeft,
                    rightFaceNormal: edge.normalRight
                )
            }
        }

        return EdgeChain(
            foundEdge: FoundEdge(segments: segments),
            startVertexIndex: backward.finalVertex,
            endVertexIndex: forward.finalVertex
        )
    }

    /// Walks outward from a vertex, greedily following the straightest continuation.
    /// Returns the traversed edges in travel order and the vertex where the walk stopped.
    private static func walk(
        fromVertex: Int,
        direction: Vector3D,
        convex: Bool,
        sharpEdges: [SharpEdge],
        vertexToEdges: [Int: [EdgeReference]],
        vertices: [Vector3D],
        maximumTurnAngle: Angle,
        visited: inout [Bool]
    ) -> (steps: [(edgeIndex: Int, reversed: Bool)], finalVertex: Int) {
        var steps: [(edgeIndex: Int, reversed: Bool)] = []
        var currentVertex = fromVertex
        var currentDirection = direction

        while let (next, nextDirection) = bestContinuation(
            fromVertex: currentVertex,
            inDirection: currentDirection,
            convex: convex,
            sharpEdges: sharpEdges,
            vertexToEdges: vertexToEdges,
            vertices: vertices,
            maximumTurnAngle: maximumTurnAngle,
            visited: visited
        ) {
            visited[next.edgeIndex] = true
            steps.append((next.edgeIndex, next.reversed))
            currentVertex = next.reversed ? sharpEdges[next.edgeIndex].vertexA : sharpEdges[next.edgeIndex].vertexB
            currentDirection = nextDirection
        }

        return (steps, currentVertex)
    }

    private static func bestContinuation(
        fromVertex: Int,
        inDirection: Vector3D,
        convex: Bool,
        sharpEdges: [SharpEdge],
        vertexToEdges: [Int: [EdgeReference]],
        vertices: [Vector3D],
        maximumTurnAngle: Angle,
        visited: [Bool]
    ) -> (EdgeReference, Vector3D)? {
        // Chains stop at junction vertices (three or more incident sharp edges); those are
        // handled separately as corners.
        guard let candidates = vertexToEdges[fromVertex], candidates.count <= 2 else { return nil }

        let magnitude = inDirection.magnitude
        guard magnitude > 1e-12 else { return nil }
        let normalizedDirection = inDirection / magnitude
        let cosMaxTurn = cos(maximumTurnAngle)

        var best: (EdgeReference, Vector3D)? = nil
        var bestDot = -Double.infinity

        for reference in candidates {
            let edge = sharpEdges[reference.edgeIndex]
            guard !visited[reference.edgeIndex], edge.isConvex == convex else { continue }

            let toVertex = reference.reversed ? edge.vertexA : edge.vertexB
            let outVector = vertices[toVertex] - vertices[fromVertex]
            guard outVector.magnitude > 1e-12 else { continue }

            let dot = normalizedDirection ⋅ outVector.normalized
            if dot >= cosMaxTurn && dot > bestDot {
                bestDot = dot
                best = (reference, outVector)
            }
        }

        return best
    }
}
