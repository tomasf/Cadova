import Foundation

extension SimplePolygonList {
    /// Align polygon vertices by minimizing total distance between consecutive layers.
    /// Uses a two-phase search: coarse sampling followed by local refinement.
    mutating func alignOffsets() {
        for i in 1..<count {
            let reference = self[i - 1]
            let candidate = self[i]
            let vertexCount = candidate.count

            guard vertexCount > 0 else { continue }

            // For small polygons, just check all offsets
            if vertexCount <= 40 {
                self[i] = candidate.shifted(bestOffset(for: candidate, relativeTo: reference, in: 0..<vertexCount))
                continue
            }

            // Coarse search: sample ~20 offsets spread across the polygon
            let coarseStride = Swift.max(1, vertexCount / 20)
            let coarseOffsets = stride(from: 0, to: vertexCount, by: coarseStride)
            let bestCoarse = bestOffset(for: candidate, relativeTo: reference, in: coarseOffsets)

            // Fine search: check all offsets within one stride of the best coarse result
            let fineStart = Swift.max(0, bestCoarse - coarseStride)
            let fineEnd = Swift.min(vertexCount, bestCoarse + coarseStride + 1)
            let bestFine = bestOffset(for: candidate, relativeTo: reference, in: fineStart..<fineEnd)

            self[i] = candidate.shifted(bestFine)
        }
    }

    /// Finds the offset that minimizes total vertex-to-vertex distance.
    private func bestOffset<S: Sequence<Int>>(
        for candidate: SimplePolygon,
        relativeTo reference: SimplePolygon,
        in offsets: S
    ) -> Int {
        var bestOffset = 0
        var bestScore = Double.infinity

        for offset in offsets {
            let score = alignmentScore(candidate: candidate, reference: reference, offset: offset)
            if score < bestScore {
                bestScore = score
                bestOffset = offset
            }
        }

        return bestOffset
    }

    /// Computes the sum of distances between corresponding vertices at the given offset.
    private func alignmentScore(candidate: SimplePolygon, reference: SimplePolygon, offset: Int) -> Double {
        let count = candidate.count
        var score = 0.0
        for i in 0..<count {
            let candidateVertex = candidate[(i + offset) % count]
            let referenceVertex = reference[i]
            score += (candidateVertex - referenceVertex).magnitude
        }
        return score
    }
}
