import Foundation

struct PolygonGroupVertex: Hashable, Codable {
    let polygonGroupIndex: Int
    let layerIndex: Int
    let pointIndex: Int
}

internal extension Mesh where Vertex == PolygonGroupVertex {
    init(polygonGroups: [(polygons: SimplePolygonList, transforms: [Transform3D])]) {
        let sideFaces = polygonGroups.map(\.0).enumerated().flatMap { polygonIndex, group in
            (0..<(group.count - 1)).flatMap { layerIndex1 in
                let layerIndex2 = layerIndex1 + 1
                return (0..<group[0].count).cyclicPairs().flatMap { pointIndex1, pointIndex2 in [
                    [
                        PolygonGroupVertex(polygonGroupIndex: polygonIndex, layerIndex: layerIndex1, pointIndex: pointIndex2),
                        PolygonGroupVertex(polygonGroupIndex: polygonIndex, layerIndex: layerIndex2, pointIndex: pointIndex2),
                        PolygonGroupVertex(polygonGroupIndex: polygonIndex, layerIndex: layerIndex2, pointIndex: pointIndex1),
                    ],[
                        PolygonGroupVertex(polygonGroupIndex: polygonIndex, layerIndex: layerIndex2, pointIndex: pointIndex1),
                        PolygonGroupVertex(polygonGroupIndex: polygonIndex, layerIndex: layerIndex1, pointIndex: pointIndex1),
                        PolygonGroupVertex(polygonGroupIndex: polygonIndex, layerIndex: layerIndex1, pointIndex: pointIndex2),
                    ]
                ]}
            }
        }

        let bottomPolygons = SimplePolygonList(polygonGroups.map { $0.polygons[0] })
        let bottomFaces = bottomPolygons.triangulated().map { a, b, c in [
            PolygonGroupVertex(polygonGroupIndex: c.polygon, layerIndex: 0, pointIndex: c.vertex),
            PolygonGroupVertex(polygonGroupIndex: b.polygon, layerIndex: 0, pointIndex: b.vertex),
            PolygonGroupVertex(polygonGroupIndex: a.polygon, layerIndex: 0, pointIndex: a.vertex),
        ]}

        let topPolygons = SimplePolygonList(polygonGroups.map { $0.polygons[$0.polygons.count - 1] })
        let topFaces = topPolygons.triangulated().map { a, b, c in [
            PolygonGroupVertex(polygonGroupIndex: a.polygon, layerIndex: polygonGroups[a.polygon].polygons.count - 1, pointIndex: a.vertex),
            PolygonGroupVertex(polygonGroupIndex: b.polygon, layerIndex: polygonGroups[b.polygon].polygons.count - 1, pointIndex: b.vertex),
            PolygonGroupVertex(polygonGroupIndex: c.polygon, layerIndex: polygonGroups[c.polygon].polygons.count - 1, pointIndex: c.vertex),
        ]}

        self.init(
            faces: sideFaces + bottomFaces + topFaces,
            name: "PolygonGroupMesh",
            cacheParameters: polygonGroups.map(\.polygons), polygonGroups.map(\.transforms)
        ) { vertex in
            let flatPoint = polygonGroups[vertex.polygonGroupIndex].polygons[vertex.layerIndex][vertex.pointIndex]
            let transform = polygonGroups[vertex.polygonGroupIndex].transforms[vertex.layerIndex]
            return transform.apply(to: Vector3D(flatPoint, z: 0))
        }
    }
}
