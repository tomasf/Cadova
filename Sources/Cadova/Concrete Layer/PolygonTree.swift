import Foundation
import ManifoldCPP
import CadovaCPP
import Cxx

// Corresponds to Clipper2's PolyTreeD
struct PolygonTree: Sendable {
    public let polygon: SimplePolygon
    public let children: [PolygonTree]

    init(polygon: SimplePolygon, children: [Self]) {
        self.polygon = polygon
        self.children = children
    }

    static let empty = PolygonTree(polygon: .init([]), children: [])
}

fileprivate extension PolygonTree {
    init(polygonNode: cadova.PolygonNode) {
        polygon = SimplePolygon(polygonNode.polygon.map { Vector2D(x: $0.x, y: $0.y) })

        // Trying to either map polygonNode.children directly or trying to access .count
        // instead of size() makes the compiler crash on Windows. I don't even- 
        children = (0..<polygonNode.children.size()).map {
            PolygonTree(polygonNode: polygonNode.children[$0]!)
        }
    }
}

extension CrossSection {
    func polygonTree() -> PolygonTree {
        let polygons = polygons()
        let tree = cadova.PolygonNode.FromPolygons(.init(polygons.map {
            .init($0.vertices.map {
                manifold.vec2($0.x, $0.y)
            })}
        ))
        guard let tree else { return .empty }

        let result = PolygonTree(polygonNode: tree)
        defer { cadova.PolygonNode.Destroy(tree) }
        return result
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
