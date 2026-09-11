import Foundation
import Manifold3D

internal struct SimplePolygonList: Sendable, Hashable, Codable {
    var polygons: [SimplePolygon] {
        // Assigning the list re-derives the digest, which walks every vertex. That is the right cost
        // once per list, and the wrong cost per edit, so there is deliberately no way to write a
        // single polygon or a single vertex in place: edit a plain `[SimplePolygon]` and assign it
        // back when you are done. The subscripts below are read-only for that reason.
        didSet { digest = Self.digest(of: polygons) }
    }

    /// The list's stable content digest, computed once at construction, so that a node built from
    /// a large polygon list walks it once rather than at every level of the tree.
    private(set) var digest: StableDigest

    init() {
        self.polygons = []
        self.digest = Self.digest(of: [])
    }

    init(_ polygons: [SimplePolygon]) {
        self.polygons = polygons
        self.digest = Self.digest(of: polygons)
    }

    init(_ polygonLists: [SimplePolygonList]) {
        self.init(polygonLists.flatMap(\.polygons))
    }

    private static func digest(of polygons: [SimplePolygon]) -> StableDigest {
        var hasher = StableHasher()
        hasher.combine(polygons)
        return hasher.finalize()
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.digest == rhs.digest
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(digest)
    }

    private enum CodingKeys: String, CodingKey {
        case polygons
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(try container.decode([SimplePolygon].self, forKey: .polygons))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(polygons, forKey: .polygons)
    }

    subscript(index: Int) -> SimplePolygon {
        polygons[index]
    }

    var count: Int { polygons.count }
    var vertexCount: Int { polygons.reduce(0) { $0 + $1.count } }

    static func +(_ lhs: SimplePolygonList, _ rhs: SimplePolygonList) -> SimplePolygonList {
        SimplePolygonList(lhs.polygons + rhs.polygons)
    }

    static func +=(_ lhs: inout SimplePolygonList, _ rhs: SimplePolygonList) {
        lhs = lhs + rhs
    }
}

extension SimplePolygonList: Collection {
    func index(after i: Int) -> Int { i + 1 }
    var startIndex: Int { 0 }
    var endIndex: Int { polygons.count }
}

extension SimplePolygonList: Transformable {
    func transformed(_ transform: Transform2D) -> Self {
        Self(polygons.map { $0.transformed(transform) })
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
        polygons[vertex.polygon][vertex.vertex]
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

    func triangulated() -> [(Vertex, Vertex, Vertex)] {
        let polygons = polygons.map(\.manifoldPolygon)
        let triangles = ManifoldPolygon.triangulate(polygons, epsilon: 1e-8)
        return triangles.map { (vertex(at: $0.a), vertex(at: $0.b), vertex(at: $0.c)) }
    }

    func refined(maxEdgeLength: Double) -> Self {
        Self(polygons.map { $0.refined(maxEdgeLength: maxEdgeLength) })
    }

    func removingRedundantCollinearPoints(tolerance: Double = 1e-6) -> Self {
        Self(polygons.map { $0.removingRedundantCollinearPoints(tolerance: tolerance) })
    }


    func vertices(transformedBy transform: Transform3D) -> [Vector3D] {
        polygons.flatMap { $0.vertices(transformedBy: transform) }
    }
}

extension D2.Concrete {
    func polygonList() -> SimplePolygonList {
        SimplePolygonList(polygons())
    }

    init(_ polygonList: SimplePolygonList) {
        self.init(polygons: polygonList.polygons.map(\.manifoldPolygon), fillRule: .nonZero)
    }
}

extension SimplePolygonList: StableHashable {
    func stableHash(into hasher: inout StableHasher) {
        hasher.combine(digest)
    }
}
