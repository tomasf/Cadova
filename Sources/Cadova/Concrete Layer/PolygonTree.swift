import Manifold3D

struct PolygonTree: Sendable {
    public let polygon: SimplePolygon
    public let children: [PolygonTree]

    init(polygon: SimplePolygon, children: [Self]) {
        self.polygon = polygon
        self.children = children
    }

    static let empty = PolygonTree(polygon: .init([]), children: [])
}

extension CrossSection {
    func polygonTree() -> PolygonTree {
        let contours = polygons().map { SimplePolygon($0) }
        guard !contours.isEmpty else { return .empty }

        let areas = contours.map(\.area)

        // For each contour, find its immediate parent: the smallest-area contour that contains it
        let parents: [Int?] = contours.indices.map { i in
            let testPoint = contours[i].vertices[0]
            return contours.indices
                .filter { j in j != i && contours[j].contains(testPoint) }
                .min(by: { areas[$0] < areas[$1] })
        }

        func buildSubtree(parentIndex: Int?) -> [PolygonTree] {
            contours.indices
                .filter { parents[$0] == parentIndex }
                .map { i in PolygonTree(polygon: contours[i], children: buildSubtree(parentIndex: i)) }
        }

        return PolygonTree(polygon: .init([]), children: buildSubtree(parentIndex: nil))
    }
}

extension PolygonTree {
    func matchesTopology(of other: PolygonTree) -> Bool {
        guard children.count == other.children.count else { return false }

        for (left, right) in zip(children, other.children) {
            guard left.matchesTopology(of: right) else { return false }
        }

        return true
    }

    func flattened() -> SimplePolygonList {
        var list = SimplePolygonList([polygon])
        for child in children {
            list += child.flattened()
        }
        return list
    }
}

private extension SimplePolygon {
    func contains(_ point: Vector2D) -> Bool {
        var inside = false
        var j = count - 1
        for i in 0..<count {
            let pi = vertices[i], pj = vertices[j]
            if (pi.y > point.y) != (pj.y > point.y),
               point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x {
                inside = !inside
            }
            j = i
        }
        return inside
    }
}
