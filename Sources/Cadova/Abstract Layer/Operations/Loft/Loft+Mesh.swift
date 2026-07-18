import Foundation

struct PolygonGroupVertex: Hashable, Codable {
    let polygonGroupIndex: Int
    let ringIndex: Int
    let pointIndex: Int
}

internal extension Mesh where Vertex == PolygonGroupVertex {
    init(polygonGroups: [(polygons: SimplePolygonList, transforms: [Transform3D])]) {
        func vertex(polygonGroupIndex: Int, ringIndex: Int, pointIndex: Int) -> PolygonGroupVertex {
            PolygonGroupVertex(polygonGroupIndex: polygonGroupIndex, ringIndex: ringIndex, pointIndex: pointIndex)
        }

        let point: @Sendable (PolygonGroupVertex) -> Vector3D = { vertex in
            let flatPoint = polygonGroups[vertex.polygonGroupIndex].polygons[vertex.ringIndex][vertex.pointIndex]
            let transform = polygonGroups[vertex.polygonGroupIndex].transforms[vertex.ringIndex]
            return transform.apply(to: Vector3D(flatPoint, z: 0))
        }

        let sideFaces = polygonGroups.map(\.0).enumerated().flatMap { polygonIndex, group in
            (0..<(group.count - 1)).flatMap { ringIndex1 in
                let ringIndex2 = ringIndex1 + 1
                return (0..<group[0].count).cyclicPairs().flatMap { pointIndex1, pointIndex2 in
                    let lower1 = vertex(polygonGroupIndex: polygonIndex, ringIndex: ringIndex1, pointIndex: pointIndex1)
                    let lower2 = vertex(polygonGroupIndex: polygonIndex, ringIndex: ringIndex1, pointIndex: pointIndex2)
                    let upper1 = vertex(polygonGroupIndex: polygonIndex, ringIndex: ringIndex2, pointIndex: pointIndex1)
                    let upper2 = vertex(polygonGroupIndex: polygonIndex, ringIndex: ringIndex2, pointIndex: pointIndex2)

                    let lower2ToUpper1 = point(lower2).distance(to: point(upper1))
                    let lower1ToUpper2 = point(lower1).distance(to: point(upper2))

                    if lower2ToUpper1 <= lower1ToUpper2 {
                        return [
                            [lower2, upper2, upper1],
                            [upper1, lower1, lower2],
                        ]
                    } else {
                        return [
                            [lower1, lower2, upper2],
                            [upper2, upper1, lower1],
                        ]
                    }
                }
            }
        }

        let bottomPolygons = SimplePolygonList(polygonGroups.map { $0.polygons[0] })
        let bottomFaces = bottomPolygons.triangulated().map { a, b, c in [
            PolygonGroupVertex(polygonGroupIndex: c.polygon, ringIndex: 0, pointIndex: c.vertex),
            PolygonGroupVertex(polygonGroupIndex: b.polygon, ringIndex: 0, pointIndex: b.vertex),
            PolygonGroupVertex(polygonGroupIndex: a.polygon, ringIndex: 0, pointIndex: a.vertex),
        ]}

        let topPolygons = SimplePolygonList(polygonGroups.map { $0.polygons[$0.polygons.count - 1] })
        let topFaces = topPolygons.triangulated().map { a, b, c in [
            PolygonGroupVertex(polygonGroupIndex: a.polygon, ringIndex: polygonGroups[a.polygon].polygons.count - 1, pointIndex: a.vertex),
            PolygonGroupVertex(polygonGroupIndex: b.polygon, ringIndex: polygonGroups[b.polygon].polygons.count - 1, pointIndex: b.vertex),
            PolygonGroupVertex(polygonGroupIndex: c.polygon, ringIndex: polygonGroups[c.polygon].polygons.count - 1, pointIndex: c.vertex),
        ]}

        self.init(
            faces: sideFaces + bottomFaces + topFaces,
            name: "PolygonGroupMesh",
            cacheParameters: polygonGroups.map(\.polygons), polygonGroups.map(\.transforms)
        ) { vertex in
            point(vertex)
        }
    }
}
