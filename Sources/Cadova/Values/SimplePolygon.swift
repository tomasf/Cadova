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

extension SimplePolygon {
    var perimeter: Double {
        vertices.wrappedPairs().map { ($1 - $0).magnitude }.reduce(0, +)
    }

    var centroid: Vector2D {
        guard !isEmpty else { return .zero }
        let sum = vertices.reduce(Vector2D.zero, +)
        return sum / Double(count)
    }

    var isConvex: Bool {
        guard count >= 3 else { return false }

        var lastCross: Double? = nil
        for (a, b, c) in vertices.wrappedTriplets() {
            let cross = (b - a) × (c - b)
            if cross != 0 {
                if let lastCross, cross.sign != lastCross.sign {
                    return false
                } else {
                    lastCross = cross
                }
            }
        }

        return true
    }

    // Shift the polygon points circularly by the given offset.
    // This changes the starting point of the polygon without altering its shape.
    func offset(_ offset: Int) -> Self {
        SimplePolygon(Array(0..<count).map {
            self[($0 + offset) % count]
        })
    }

    func resampled(count targetCount: Int) -> Self {
        // Resample the polygon points so that the polygon has exactly targetCount points evenly spaced along its perimeter.
        // This is done by walking along the polygon edges and interpolating points at regular intervals.
        guard vertices.count >= 2, targetCount >= 2 else { return self }

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

            // Advance along segments until the targetDistance fits within the current segment
            while accumulatedLength + segmentLength < targetDistance {
                accumulatedLength += segmentLength
                segmentIndex = (segmentIndex + 1) % self.count
                segmentStart = self[segmentIndex]
                segmentEnd = self[(segmentIndex + 1) % self.count]
                segmentLength = (segmentEnd - segmentStart).magnitude
            }

            // Interpolate between segmentStart and segmentEnd to find the exact point
            let localT = (targetDistance - accumulatedLength) / segmentLength
            let point = segmentStart + (segmentEnd - segmentStart) * localT
            result.append(point)
        }

        return .init(result)
    }

    func vertices(at z: Double) -> [Vector3D] {
        vertices.map { Vector3D($0, z: z) }
    }

    func blended(with other: Self, t: Double) -> Self {
        Self(zip(vertices, other.vertices).map { a, b in
            a + (b - a) * t
        })
    }

    func transformed(_ transform: Transform2D) -> Self {
        Self(vertices.map { transform.apply(to: $0) })
    }
}
