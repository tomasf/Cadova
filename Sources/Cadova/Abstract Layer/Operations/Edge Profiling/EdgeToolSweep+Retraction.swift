import Foundation

internal extension EdgeToolSweep {
    /// Shortens an open chain from its ends, dropping fully consumed segments and trimming
    /// the remainder — retractions routinely exceed individual segment lengths on finely
    /// segmented curved chains. Chains too short to retract keep their flush ends.
    static func retracted(_ segments: [EdgeSegment], start: Double, end: Double) -> [EdgeSegment] {
        guard start > 0 || end > 0 else { return segments }
        let totalLength = segments.reduce(0) { $0 + $1.length }
        guard start + end < totalLength * 0.9 else { return segments }

        var result = segments[...]

        var remaining = start
        while let first = result.first, remaining >= first.length - 1e-9 {
            remaining -= first.length
            result.removeFirst()
        }
        if remaining > 0, let first = result.first {
            result[result.startIndex] = EdgeSegment(
                start: first.start + first.direction.unitVector * remaining,
                end: first.end,
                leftFaceNormal: first.leftFaceNormal,
                rightFaceNormal: first.rightFaceNormal
            )
        }

        remaining = end
        while let last = result.last, remaining >= last.length - 1e-9 {
            remaining -= last.length
            result.removeLast()
        }
        if remaining > 0, let last = result.last {
            result[result.endIndex - 1] = EdgeSegment(
                start: last.start,
                end: last.end - last.direction.unitVector * remaining,
                leftFaceNormal: last.leftFaceNormal,
                rightFaceNormal: last.rightFaceNormal
            )
        }

        return Array(result)
    }

    /// Splits segments at the given arc-length positions along the chain, so that rings can
    /// exist there. Positions outside an open chain are ignored; positions on a closed chain
    /// wrap around. Cuts landing within a small tolerance of an existing joint are skipped.
    static func subdivided(
        _ segments: [EdgeSegment],
        atArcPositions positions: [Double],
        isClosed: Bool,
        chainLength: Double
    ) -> [EdgeSegment] {
        let cuts: [Double] = positions.compactMap { position in
            if isClosed {
                let wrapped = position.truncatingRemainder(dividingBy: chainLength)
                return wrapped < 0 ? wrapped + chainLength : wrapped
            } else {
                return (position > 0 && position < chainLength) ? position : nil
            }
        }.sorted()

        var result: [EdgeSegment] = []
        var segmentStart = 0.0
        var cutIndex = 0
        for segment in segments {
            let segmentEnd = segmentStart + segment.length
            var pieceStart = segment.start
            var pieceArc = segmentStart
            while cutIndex < cuts.count, cuts[cutIndex] < segmentEnd - 1e-6 {
                let cut = cuts[cutIndex]
                cutIndex += 1
                guard cut > pieceArc + 1e-6 else { continue }
                let point = segment.start + segment.direction.unitVector * (cut - segmentStart)
                result.append(EdgeSegment(
                    start: pieceStart, end: point,
                    leftFaceNormal: segment.leftFaceNormal, rightFaceNormal: segment.rightFaceNormal
                ))
                pieceStart = point
                pieceArc = cut
            }
            result.append(EdgeSegment(
                start: pieceStart, end: segment.end,
                leftFaceNormal: segment.leftFaceNormal, rightFaceNormal: segment.rightFaceNormal
            ))
            segmentStart = segmentEnd
        }
        return result
    }
}
