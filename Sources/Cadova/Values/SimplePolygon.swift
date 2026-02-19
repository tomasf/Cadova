import Foundation

internal struct SimplePolygon: Sendable, Hashable, Codable {
    var vertices: [Vector2D]

    init(_ vertices: [Vector2D]) {
        self.vertices = vertices
    }

    subscript(index: Int) -> Vector2D {
        get { vertices[index] }
        set { vertices[index] = newValue }
    }

    var count: Int { vertices.count }
    var isEmpty: Bool { vertices.isEmpty }
}

extension SimplePolygon {
    init(_ manifoldPolygon: ManifoldPolygon) {
        self.init(manifoldPolygon.vertices)
    }

    var manifoldPolygon: ManifoldPolygon {
        .init(vertices: vertices)
    }
}

extension SimplePolygon: Collection {
    func index(after i: Int) -> Int { i + 1 }
    var startIndex: Int { 0 }
    var endIndex: Int { vertices.count }
}

extension SimplePolygon: Transformable {
    func transformed(_ transform: Transform2D) -> Self {
        Self(vertices.map { transform.apply(to: $0) })
    }
}

extension SimplePolygon {
    var perimeter: Double {
        vertices.wrappedPairs().map { ($1 - $0).magnitude }.reduce(0, +)
    }

    var centroid: Vector2D {
        guard !isEmpty else { return .zero }
        return vertices.reduce(Vector2D.zero, +) / Double(count)
    }

    var isConvex: Bool {
        guard count >= 3 else { return false }

        var lastCross: Double? = nil
        for (a, b, c) in vertices.wrappedTriplets() {
            let cross = (b - a) × (c - b)
            guard cross != 0 else { continue }

            if let lastCross, cross.sign != lastCross.sign {
                return false
            } else {
                lastCross = cross
            }
        }

        return true
    }

    // Shift the polygon points circularly by the given offset.
    // This changes the starting point of the polygon without altering its shape.
    func shifted(_ offset: Int) -> Self {
        SimplePolygon(Array(0..<count).map {
            self[($0 + offset) % count]
        })
    }

    func resampled(count targetCount: Int) -> Self {
        guard vertices.count >= 2, targetCount >= 2 else { return self }

        // Detect corner vertices: those where the turn angle is at least 30°.
        // Turn angle = angle between the incoming and outgoing edge directions.
        // cos(30°) ≈ 0.866; a vertex is a corner when dot(in, out) / (|in| * |out|) ≤ cos(30°).
        let cosThreshold = cos(30.0 * .pi / 180.0)
        let cornerIndices = (0..<count).filter { i in
            let incoming = vertices[i] - vertices[(i + count - 1) % count]
            let outgoing = vertices[(i + 1) % count] - vertices[i]
            let denom = incoming.magnitude * outgoing.magnitude
            guard denom > 0 else { return false }
            return (incoming.x * outgoing.x + incoming.y * outgoing.y) / denom <= cosThreshold
        }

        // If no corners are detected, or the target count can't fit all corners,
        // fall back to classic even resampling (correct for smooth shapes like circles).
        guard !cornerIndices.isEmpty, targetCount > cornerIndices.count else {
            return evenlyResampled(count: targetCount)
        }

        let n = cornerIndices.count
        let additionalPoints = targetCount - n

        // Compute the arc length of each inter-corner segment.
        var segmentLengths = [Double](repeating: 0, count: n)
        for i in 0..<n {
            var j = cornerIndices[i]
            let end = cornerIndices[(i + 1) % n]
            while j != end {
                let next = (j + 1) % count
                segmentLengths[i] += (vertices[next] - vertices[j]).magnitude
                j = next
            }
        }
        let totalLength = segmentLengths.reduce(0, +)

        // Distribute the additional points among segments proportionally to their length,
        // using the largest-remainder method to ensure the total is exactly right.
        let rawCounts = segmentLengths.map { Double(additionalPoints) * $0 / totalLength }
        var pointsPerSegment = rawCounts.map { Int($0) }
        let deficit = additionalPoints - pointsPerSegment.reduce(0, +)
        for i in rawCounts.indices.sorted(by: { rawCounts[$0] - Double(pointsPerSegment[$0]) > rawCounts[$1] - Double(pointsPerSegment[$1]) }).prefix(deficit) {
            pointsPerSegment[i] += 1
        }

        // Build the result: for each inter-corner segment, emit the leading corner vertex
        // followed by evenly-spaced interior points along the segment's edges.
        var result: [Vector2D] = []
        for i in 0..<n {
            result.append(vertices[cornerIndices[i]])

            let extra = pointsPerSegment[i]
            guard extra > 0 else { continue }

            let segLen = segmentLengths[i]
            let spacing = segLen / Double(extra + 1)
            var accumulated = 0.0
            var edgeStart = cornerIndices[i]
            var edgeEnd = (edgeStart + 1) % count
            var edgeLen = (vertices[edgeEnd] - vertices[edgeStart]).magnitude

            for k in 1...extra {
                let target = Double(k) * spacing
                while accumulated + edgeLen < target {
                    accumulated += edgeLen
                    edgeStart = edgeEnd
                    edgeEnd = (edgeStart + 1) % count
                    edgeLen = (vertices[edgeEnd] - vertices[edgeStart]).magnitude
                }
                let t = edgeLen > 0 ? (target - accumulated) / edgeLen : 0
                result.append(vertices[edgeStart] + (vertices[edgeEnd] - vertices[edgeStart]) * t)
            }
        }

        return .init(result)
    }

    private func evenlyResampled(count targetCount: Int) -> Self {
        // Distribute targetCount points evenly along the perimeter, ignoring original vertices.
        let totalLength = perimeter
        let spacing = totalLength / Double(targetCount)
        var result: [Vector2D] = []

        var accumulatedLength = 0.0
        var segmentIndex = 0
        var segmentStart = self[0]
        var segmentEnd = self[1]
        var segmentLength = (segmentEnd - segmentStart).magnitude

        for i in 0..<targetCount {
            let targetDistance = Double(i) * spacing

            while accumulatedLength + segmentLength < targetDistance {
                accumulatedLength += segmentLength
                segmentIndex = (segmentIndex + 1) % self.count
                segmentStart = self[segmentIndex]
                segmentEnd = self[(segmentIndex + 1) % self.count]
                segmentLength = (segmentEnd - segmentStart).magnitude
            }

            let localT = (targetDistance - accumulatedLength) / segmentLength
            result.append(segmentStart + (segmentEnd - segmentStart) * localT)
        }

        return .init(result)
    }

    func vertices(at z: Double) -> [Vector3D] {
        vertices.map { Vector3D($0, z: z) }
    }

    func blended(with other: Self, t: Double) -> Self {
        Self(zip(vertices, other.vertices).map { $0 + ($1 - $0) * t })
    }

    func refined(maxEdgeLength: Double) -> Self {
        Self([vertices[0]] + vertices.paired().flatMap { a, b -> [Vector2D] in
            let segmentCount = ceil((b - a).magnitude / maxEdgeLength)
            guard segmentCount > 1 else { return [b] }
            return (1...Int(segmentCount)).map { a + (b - a) * Double($0) / Double(segmentCount) }
        })
    }

    var length: Double {
        vertices.paired().map { $0.distance(to: $1) }.reduce(0, +)
    }

    var area: Double {
        abs(
            vertices.wrappedPairs()
                .map { $0.x * $1.y - $0.y * $1.x }
                .reduce(0, +)
        ) / 2.0
    }

    var boundingBox: BoundingBox2D {
        .init(vertices)
    }

    func triangulated() -> [(Int, Int, Int)] {
        ManifoldPolygon(vertices: vertices).triangulate(epsilon: 1e-8)
            .map { ($0.a, $0.b, $0.c) }
    }
}
