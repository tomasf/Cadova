import Foundation

/// An edge feature on a mesh, composed of one or more connected segments.
///
/// An `Edge` represents a user-facing edge concept like the rim of a cylinder
/// or the corner of a box. It may consist of a single segment (like a box corner)
/// or many segments forming a continuous path (like a circular rim).
///
/// Use ``EdgeSelection`` to find and filter edges, then apply operations like
/// filleting or chamfering.
///
public struct Edge: Sendable {
    /// The segments that make up this edge, in connected order.
    public let segments: [EdgeSegment]

    /// Whether the edge forms a closed loop.
    public let isClosed: Bool

    internal init(segments: [EdgeSegment], isClosed: Bool) {
        self.segments = segments
        self.isClosed = isClosed
    }
}

public extension Edge {
    /// Returns the total length of this edge.
    func length(in topology: MeshTopology) -> Double {
        segments.reduce(0) { $0 + $1.length(in: topology) }
    }

    /// Returns all unique vertex indices along this edge.
    func vertexIndices() -> [Int] {
        guard !segments.isEmpty else { return [] }

        var indices: [Int] = []
        indices.reserveCapacity(segments.count + (isClosed ? 0 : 1))

        // Find the starting vertex and build the ordered list
        if isClosed {
            // For closed loops, start at the smallest vertex index for determinism
            let allVertices = segments.flatMap { [$0.v0, $0.v1] }
            var current = allVertices.min()!
            for segment in segments {
                indices.append(current)
                current = segment.v0 == current ? segment.v1 : segment.v0
            }
        } else {
            // For open edges, find endpoints (vertices that appear only once)
            let allVertices = segments.flatMap { [$0.v0, $0.v1] }
            let vertexCounts = Dictionary(grouping: allVertices, by: { $0 }).mapValues { $0.count }
            let endpoints = vertexCounts.filter { $0.value == 1 }.map { $0.key }
            guard let startVertex = endpoints.min() else {
                return []
            }

            var current = startVertex
            indices.append(current)
            var remaining = segments

            while !remaining.isEmpty {
                guard let nextIndex = remaining.firstIndex(where: { $0.v0 == current || $0.v1 == current }) else {
                    break
                }
                let nextSegment = remaining.remove(at: nextIndex)
                current = nextSegment.v0 == current ? nextSegment.v1 : nextSegment.v0
                indices.append(current)
            }
        }

        return indices
    }

    /// Returns the vertices along this edge as 3D points.
    func vertices(in topology: MeshTopology) -> [Vector3D] {
        vertexIndices().map { topology.vertices[$0] }
    }
}

// MARK: - Edge Building from Segments

public extension MeshTopology {
    /// Groups edge segments into connected edges.
    ///
    /// Two segments are considered connected if they share a vertex and the angle
    /// between them is within the continuity threshold.
    ///
    /// - Parameters:
    ///   - segments: The segments to group into edges.
    ///   - continuityThreshold: The maximum angle between connected segments for them
    ///     to be considered part of the same edge. Defaults to 30°.
    /// - Returns: An array of edges.
    ///
    func buildEdges(from segments: [EdgeSegment], continuityThreshold: Angle = 30°) -> [Edge] {
        guard !segments.isEmpty else { return [] }

        // Build vertex-to-segment adjacency
        var vertexToSegments: [Int: [EdgeSegment]] = [:]
        for segment in segments {
            vertexToSegments[segment.v0, default: []].append(segment)
            vertexToSegments[segment.v1, default: []].append(segment)
        }

        var remaining = Set(segments)
        var edges: [Edge] = []

        // Process segments in deterministic order (by vertex indices)
        while let startSegment = remaining.min(by: { ($0.v0, $0.v1) < ($1.v0, $1.v1) }) {
            remaining.remove(startSegment)

            var edgeSegments: [EdgeSegment] = [startSegment]
            var isClosed = false

            // Extend in both directions
            for startFromV1 in [false, true] {
                var currentSegment = startSegment
                var currentVertex = startFromV1 ? startSegment.v1 : startSegment.v0

                while true {
                    // Find candidate segments at this vertex
                    let candidates = vertexToSegments[currentVertex, default: []]
                        .filter { remaining.contains($0) }

                    // Find the best continuation (smallest angle deviation)
                    let currentDirection = segmentDirection(currentSegment, from: currentVertex == currentSegment.v1 ? currentSegment.v0 : currentSegment.v1)

                    var bestSegment: EdgeSegment?
                    var bestAngle: Angle = 360°

                    for candidate in candidates {
                        let candidateDirection = segmentDirection(candidate, from: currentVertex)
                        let angle: Angle = acos((currentDirection ⋅ candidateDirection).clamped(to: -1...1))

                        if angle <= continuityThreshold && angle < bestAngle {
                            bestAngle = angle
                            bestSegment = candidate
                        }
                    }

                    guard let nextSegment = bestSegment else {
                        break
                    }

                    remaining.remove(nextSegment)
                    let nextVertex = nextSegment.v0 == currentVertex ? nextSegment.v1 : nextSegment.v0

                    // Check if we've closed the loop
                    if startFromV1 {
                        edgeSegments.append(nextSegment)
                    } else {
                        edgeSegments.insert(nextSegment, at: 0)
                    }

                    if nextVertex == (startFromV1 ? startSegment.v0 : startSegment.v1) {
                        isClosed = true
                        break
                    }

                    currentSegment = nextSegment
                    currentVertex = nextVertex
                }

                if isClosed { break }
            }

            edges.append(Edge(segments: edgeSegments, isClosed: isClosed))
        }

        return edges
    }

    /// Returns the direction vector of a segment pointing away from the given vertex.
    private func segmentDirection(_ segment: EdgeSegment, from vertex: Int) -> Vector3D {
        let (p0, p1) = segment.vertices(in: self)
        if segment.v0 == vertex {
            return (p1 - p0).normalized
        } else {
            return (p0 - p1).normalized
        }
    }
}
