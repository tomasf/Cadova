import Foundation
import Manifold3D

internal struct SimplePolygonList: Sendable, Hashable, Codable {
    var polygons: [SimplePolygon]

    init() {
        self.polygons = []
    }

    init(_ polygons: [SimplePolygon]) {
        self.polygons = polygons
    }

    subscript(index: Int) -> SimplePolygon {
        get { polygons[index] }
        set { polygons[index] = newValue }
    }

    var count: Int { polygons.count }

    static func +(_ lhs: SimplePolygonList, _ rhs: SimplePolygonList) -> SimplePolygonList {
        SimplePolygonList(lhs.polygons + rhs.polygons)
    }

    static func +=(_ lhs: inout SimplePolygonList, _ rhs: SimplePolygonList) {
        lhs = lhs + rhs
    }
}

extension SimplePolygonList {
    init(_ manifoldPolygons: [ManifoldPolygon]) {
        self.init(manifoldPolygons.map { SimplePolygon($0) })
    }
}

extension SimplePolygonList {
    typealias Vertex = (polygon: Int, vertex: Int)

    subscript(vertex: Vertex) -> Vector2D {
        get { polygons[vertex.polygon][vertex.vertex] }
        set { polygons[vertex.polygon][vertex.vertex] = newValue }
    }

    func vertex(at index: Int) -> Vertex {
        var offset = index
        for (polygonIndex, polygon) in polygons.enumerated() {
            if polygon.count > offset {
                return (polygonIndex, offset)
            } else {
                offset -= polygon.count
            }
        }
        preconditionFailure("Index out of range")
    }

    func triangulate() -> [(Vertex, Vertex, Vertex)] {
        let polygons = polygons.map(\.manifoldPolygon)
        let triangles = ManifoldPolygon.triangulate(polygons, epsilon: 1e-8)
        return triangles.map { (vertex(at: $0.a), vertex(at: $0.b), vertex(at: $0.c)) }
    }

    func transformed(_ transform: Transform2D) -> Self {
        Self(polygons.map { $0.transformed(transform) })
    }

    func vertices(at z: Double) -> [Vector3D] {
        polygons.flatMap { $0.vertices(at: z) }
    }
}

extension SimplePolygonList {
    // Align by minimizing total distance between consecutive layers
    // This can totally be optimized
    mutating func alignOffsets() {
        for i in 1..<count {
            let reference = self[i - 1]
            let candidate = self[i]

            var bestOffset = 0
            var bestScore = Double.infinity

            for offset in 0..<candidate.count {
                let shifted = candidate.shifted(offset)

                let score = shifted.vertices.enumerated().map { i, v in (v - reference[i]).magnitude }.reduce(0, +)
                if score < bestScore {
                    bestScore = score
                    bestOffset = offset
                }
            }

            self[i] = candidate.shifted(bestOffset)
        }
    }
}

extension D2.Concrete {
    func polygonList() -> SimplePolygonList {
        SimplePolygonList(polygons())
    }
}
