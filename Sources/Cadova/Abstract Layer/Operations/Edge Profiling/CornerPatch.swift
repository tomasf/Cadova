import Foundation

/// Junction analysis for edge shaping.
///
/// Where shaped edges share an endpoint, the individual swept tools need coordination:
/// - Two chains of the same convexity continuing through a shared endpoint are merged into
///   one chain, so the joint becomes an ordinary mitered vertex.
/// - Where more chains meet (like three chamfered edges at a box corner), each chain's tool
///   is retracted from the corner and the gap is covered by a corner patch: the convex hull
///   of the terminal cross-sections, with a sphere subtracted for fillets to produce a round
///   ball corner.
///
internal enum EdgeJunctionPlanner {
    /// How far past the corner vertex the patch hull extends, as a fraction of the shape's setback.
    private static let apexOvershootFraction = 0.5

    struct Retraction {
        var start: Double = 0
        var end: Double = 0
    }

    struct ChainEnd {
        let edgeIndex: Int
        let atStart: Bool
    }

    /// A corner patch at a junction where multiple shaped chains meet.
    struct Patch {
        let isConvex: Bool
        let ends: [ChainEnd]
        let apexPoint: Vector3D
        let sphere: (center: Vector3D, radius: Double)?
    }

    struct Plan {
        var edges: [FoundEdge]
        var retractions: [Retraction]  // parallel to edges
        var patches: [Patch]
    }

    static func plan(edges: [FoundEdge], shape: EdgeShape) -> Plan {
        var edges = mergingContinuingChains(edges)
        edges.sort {
            isOrderedBefore($0.segments.first?.start ?? .zero, $1.segments.first?.start ?? .zero)
        }

        var retractions = [Retraction](repeating: Retraction(), count: edges.count)
        var patches: [Patch] = []

        for (position, ends) in junctions(in: edges) {
            guard ends.count >= 2 else { continue }
            let convexities = Set(ends.map { edges[$0.edgeIndex].isConvex })
            // Junctions where cuts meet fills are left as flush ends
            guard convexities.count == 1, let isConvex = convexities.first else { continue }

            guard let patch = makePatch(
                at: position, ends: ends, isConvex: isConvex,
                edges: edges, shape: shape, retractions: &retractions
            ) else { continue }
            patches.append(patch)
        }

        return Plan(edges: edges, retractions: retractions, patches: patches)
    }

    // MARK: - Junction discovery

    private static func junctions(in edges: [FoundEdge]) -> [(position: Vector3D, ends: [ChainEnd])] {
        var map: [Vector3D: [ChainEnd]] = [:]
        for (index, edge) in edges.enumerated() where !edge.isClosed {
            guard let first = edge.segments.first, let last = edge.segments.last else { continue }
            map[first.start, default: []].append(ChainEnd(edgeIndex: index, atStart: true))
            map[last.end, default: []].append(ChainEnd(edgeIndex: index, atStart: false))
        }
        return map.map { (position: $0.key, ends: $0.value) }
            .sorted { isOrderedBefore($0.position, $1.position) }
    }

    private static func isOrderedBefore(_ a: Vector3D, _ b: Vector3D) -> Bool {
        (a.x, a.y, a.z) < (b.x, b.y, b.z)
    }

    // MARK: - Merging

    /// Repeatedly splices pairs of same-convexity chains that meet alone at a shared endpoint.
    /// A chain whose own two ends meet becomes a closed loop implicitly.
    private static func mergingContinuingChains(_ edges: [FoundEdge]) -> [FoundEdge] {
        var edges = edges

        while let merge: (Int, Int, FoundEdge) = {
            for (position, ends) in junctions(in: edges) where ends.count == 2 {
                let (a, b) = (ends[0], ends[1])
                guard a.edgeIndex != b.edgeIndex,
                      edges[a.edgeIndex].isConvex == edges[b.edgeIndex].isConvex
                else { continue }
                return (a.edgeIndex, b.edgeIndex, spliced(edges[a.edgeIndex], a, edges[b.edgeIndex], b))
            }
            return nil
        }() {
            let (indexA, indexB, combined) = merge
            edges.remove(at: max(indexA, indexB))
            edges.remove(at: min(indexA, indexB))
            edges.append(combined)
        }

        return edges
    }

    /// Joins two chains at a shared endpoint into one continuous chain.
    private static func spliced(
        _ edgeA: FoundEdge, _ endA: ChainEnd,
        _ edgeB: FoundEdge, _ endB: ChainEnd
    ) -> FoundEdge {
        // Orient A to arrive at the junction, and B to leave from it
        let head = endA.atStart ? edgeA.reversed : edgeA
        let tail = endB.atStart ? edgeB : edgeB.reversed
        return FoundEdge(segments: head.segments + tail.segments)
    }

    // MARK: - Patches

    private static func makePatch(
        at position: Vector3D,
        ends: [ChainEnd],
        isConvex: Bool,
        edges: [FoundEdge],
        shape: EdgeShape,
        retractions: inout [Retraction]
    ) -> Patch? {
        struct EndInfo {
            let end: ChainEnd
            let intoChain: Vector3D      // unit direction from the junction into the chain
            let terminalSegment: EdgeSegment
        }

        let infos: [EndInfo] = ends.compactMap { end in
            let edge = edges[end.edgeIndex]
            guard let segment = end.atStart ? edge.segments.first : edge.segments.last else { return nil }
            let direction = end.atStart ? segment.direction.unitVector : -segment.direction.unitVector
            return EndInfo(end: end, intoChain: direction, terminalSegment: segment)
        }
        guard infos.count == ends.count else { return nil }

        // Gather the distinct faces adjacent to the junction's shaped edges,
        // and the corner plane offset for each
        var faceNormals: [Vector3D] = []
        var faceOffsets: [[Double]] = []
        for info in infos {
            let wedgeAngle = info.terminalSegment.wedgeAngle
            let offset = shape.cornerPlaneOffset(wedgeAngle: wedgeAngle)
            for normal in [info.terminalSegment.leftFaceNormal.unitVector, info.terminalSegment.rightFaceNormal.unitVector] {
                if let index = faceNormals.firstIndex(where: { ($0 ⋅ normal) > 1 - 1e-6 }) {
                    faceOffsets[index].append(offset)
                } else {
                    faceNormals.append(normal)
                    faceOffsets.append([offset])
                }
            }
        }

        var sphere: (center: Vector3D, radius: Double)?
        var retractionAmounts: [Double]

        if faceNormals.count == 3,
           let center = cornerCenter(
               junction: position, normals: faceNormals,
               offsets: faceOffsets.map { $0.reduce(0, +) / Double($0.count) },
               isConvex: isConvex
           )
        {
            retractionAmounts = infos.map { max(($0.intoChain ⋅ (center - position)), 0) }
            // A depth-based fillet's equivalent radius depends on the wedge angle; average the
            // meeting edges' angles as a representative value (exact when they agree, as at a
            // uniform corner like a box's).
            let averageWedgeAngle = Angle(
                degrees: infos.map { $0.terminalSegment.wedgeAngle.degrees }.reduce(0, +) / Double(infos.count)
            )
            if let radius = shape.filletRadius(wedgeAngle: averageWedgeAngle) {
                sphere = (center: center, radius: radius)
            }
        } else {
            // No well-defined corner center; retract by the setback and rely on the hull alone
            retractionAmounts = infos.map { shape.tangentSetback(wedgeAngle: $0.terminalSegment.wedgeAngle) }
        }

        for (info, amount) in zip(infos, retractionAmounts) {
            if info.end.atStart {
                retractions[info.end.edgeIndex].start = amount
            } else {
                retractions[info.end.edgeIndex].end = amount
            }
        }

        let maxSetback = infos.map { shape.tangentSetback(wedgeAngle: $0.terminalSegment.wedgeAngle) }.max() ?? 0
        let outward = -infos.reduce(Vector3D.zero) { $0 + $1.intoChain }
        let apexDirection = outward.magnitude > 1e-9 ? outward.normalized : -infos[0].intoChain
        let apexPoint = position + apexDirection * maxSetback * apexOvershootFraction

        return Patch(isConvex: isConvex, ends: ends, apexPoint: apexPoint, sphere: sphere)
    }

    /// Finds the point at the given distances inside (convex) or outside (concave) each of
    /// three face planes through the junction, by solving the linear system with Cramer's rule.
    private static func cornerCenter(
        junction: Vector3D,
        normals: [Vector3D],
        offsets: [Double],
        isConvex: Bool
    ) -> Vector3D? {
        let (n1, n2, n3) = (normals[0], normals[1], normals[2])
        let determinant = n1 ⋅ (n2 × n3)
        guard abs(determinant) > 1e-9 else { return nil }

        let sign = isConvex ? -1.0 : 1.0
        let solution = ((n2 × n3) * offsets[0] + (n3 × n1) * offsets[1] + (n1 × n2) * offsets[2]) / determinant
        return junction + solution * sign
    }
}

internal extension FoundEdge {
    var reversed: FoundEdge {
        FoundEdge(segments: segments.reversed().map(\.flipped))
    }
}

internal extension EdgeSegment {
    var flipped: EdgeSegment {
        EdgeSegment(start: end, end: start, leftFaceNormal: rightFaceNormal, rightFaceNormal: leftFaceNormal)
    }
}
