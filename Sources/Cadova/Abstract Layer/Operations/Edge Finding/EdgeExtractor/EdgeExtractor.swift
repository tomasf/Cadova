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
    internal typealias MeshTriangle = Manifold3D.Triangle

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
}
