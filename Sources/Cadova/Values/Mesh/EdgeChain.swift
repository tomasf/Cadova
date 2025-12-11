import Foundation

/// A chain of connected edges that form a continuous path along a mesh.
///
/// Edge chains are useful for identifying features like sharp edges that
/// run continuously along a geometry.
///
public struct EdgeChain: Sendable {
    /// The edges in this chain, in connected order.
    public let edges: [MeshEdge]

    /// Whether the chain forms a closed loop.
    public let isClosed: Bool

    internal init(edges: [MeshEdge], isClosed: Bool) {
        self.edges = edges
        self.isClosed = isClosed
    }
}

public extension EdgeChain {
    /// Returns the total length of this edge chain.
    func length(in mesh: MeshTopology) -> Double {
        edges.reduce(0) { $0 + $1.length(in: mesh) }
    }

    /// Returns all unique vertices in this chain.
    func vertexIndices() -> [Int] {
        guard !edges.isEmpty else { return [] }

        var indices: [Int] = []
        indices.reserveCapacity(edges.count + (isClosed ? 0 : 1))

        // Find the starting vertex and build the ordered list
        if isClosed {
            // For closed loops, start at the smallest vertex index for determinism
            let allVertices = edges.flatMap { [$0.v0, $0.v1] }
            var current = allVertices.min()!
            for edge in edges {
                indices.append(current)
                current = edge.v0 == current ? edge.v1 : edge.v0
            }
        } else {
            // For open chains, find endpoints (vertices that appear only once)
            let allVertices = edges.flatMap { [$0.v0, $0.v1] }
            let vertexCounts = Dictionary(grouping: allVertices, by: { $0 }).mapValues { $0.count }
            let endpoints = vertexCounts.filter { $0.value == 1 }.map { $0.key }
            guard let startVertex = endpoints.min() else {
                return []
            }

            var current = startVertex
            indices.append(current)
            var remaining = edges

            while !remaining.isEmpty {
                guard let nextEdgeIndex = remaining.firstIndex(where: { $0.v0 == current || $0.v1 == current }) else {
                    break
                }
                let nextEdge = remaining.remove(at: nextEdgeIndex)
                current = nextEdge.v0 == current ? nextEdge.v1 : nextEdge.v0
                indices.append(current)
            }
        }

        return indices
    }

    /// Returns the vertices of this chain as 3D points.
    func vertices(in mesh: MeshTopology) -> [Vector3D] {
        vertexIndices().map { mesh.vertices[$0] }
    }
}

// MARK: - Edge Chaining Algorithm

public extension MeshTopology {
    /// Groups edges into connected chains.
    ///
    /// Two edges are considered connected if they share a vertex and the angle
    /// between them is within the continuity threshold.
    ///
    /// - Parameters:
    ///   - edges: The edges to chain together.
    ///   - continuityThreshold: The maximum angle between connected edges for them
    ///     to be considered part of the same chain. Defaults to 30°.
    /// - Returns: An array of edge chains.
    ///
    func chainEdges(_ edges: [MeshEdge], continuityThreshold: Angle = 30°) -> [EdgeChain] {
        guard !edges.isEmpty else { return [] }

        // Build vertex-to-edge adjacency
        var vertexToEdges: [Int: [MeshEdge]] = [:]
        for edge in edges {
            vertexToEdges[edge.v0, default: []].append(edge)
            vertexToEdges[edge.v1, default: []].append(edge)
        }

        var remaining = Set(edges)
        var chains: [EdgeChain] = []

        // Process edges in deterministic order (by vertex indices)
        while let startEdge = remaining.min(by: { ($0.v0, $0.v1) < ($1.v0, $1.v1) }) {
            remaining.remove(startEdge)

            var chainEdges: [MeshEdge] = [startEdge]
            var isClosed = false

            // Extend in both directions
            for startFromV1 in [false, true] {
                var currentEdge = startEdge
                var currentVertex = startFromV1 ? startEdge.v1 : startEdge.v0

                while true {
                    // Find candidate edges at this vertex
                    let candidates = vertexToEdges[currentVertex, default: []]
                        .filter { remaining.contains($0) }

                    // Find the best continuation (smallest angle deviation)
                    let currentDirection = edgeDirection(currentEdge, from: currentVertex == currentEdge.v1 ? currentEdge.v0 : currentEdge.v1)

                    var bestEdge: MeshEdge?
                    var bestAngle: Angle = 360°

                    for candidate in candidates {
                        let candidateDirection = edgeDirection(candidate, from: currentVertex)
                        let angle: Angle = acos((currentDirection ⋅ candidateDirection).clamped(to: -1...1))

                        if angle <= continuityThreshold && angle < bestAngle {
                            bestAngle = angle
                            bestEdge = candidate
                        }
                    }

                    guard let nextEdge = bestEdge else {
                        break
                    }

                    remaining.remove(nextEdge)
                    let nextVertex = nextEdge.v0 == currentVertex ? nextEdge.v1 : nextEdge.v0

                    // Check if we've closed the loop
                    if startFromV1 {
                        chainEdges.append(nextEdge)
                    } else {
                        chainEdges.insert(nextEdge, at: 0)
                    }

                    if nextVertex == (startFromV1 ? startEdge.v0 : startEdge.v1) {
                        isClosed = true
                        break
                    }

                    currentEdge = nextEdge
                    currentVertex = nextVertex
                }

                if isClosed { break }
            }

            chains.append(EdgeChain(edges: chainEdges, isClosed: isClosed))
        }

        return chains
    }

    /// Returns the direction vector of an edge pointing away from the given vertex.
    private func edgeDirection(_ edge: MeshEdge, from vertex: Int) -> Vector3D {
        let (p0, p1) = edge.vertices(in: self)
        if edge.v0 == vertex {
            return (p1 - p0).normalized
        } else {
            return (p0 - p1).normalized
        }
    }
}
