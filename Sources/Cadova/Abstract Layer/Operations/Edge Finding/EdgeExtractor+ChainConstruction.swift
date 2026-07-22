import Foundation
import Manifold3D

internal extension EdgeExtractor {
    struct EdgeReference {
        let edgeIndex: Int
        let reversed: Bool  // true when this edge is entered via vertexB (traveling B→A)
    }

    static func buildVertexToEdgesMap(sharpEdges: [SharpEdge]) -> [Int: [EdgeReference]] {
        var map: [Int: [EdgeReference]] = [:]
        map.reserveCapacity(sharpEdges.count)

        for (index, edge) in sharpEdges.enumerated() {
            map[edge.vertexA, default: []].append(EdgeReference(edgeIndex: index, reversed: false))
            map[edge.vertexB, default: []].append(EdgeReference(edgeIndex: index, reversed: true))
        }

        return map
    }

    static func buildAllChains(
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
