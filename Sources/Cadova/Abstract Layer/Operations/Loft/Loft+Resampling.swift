import Foundation
import Manifold3D

internal extension Loft.LayerInterpolation {
    func resampledLoft(treeLayers: [TreeLayer], in environment: EnvironmentValues) async -> any Geometry3D {
        var groups = buildPolygonGroups(layerTrees: treeLayers.map(\.1))

        for (index, layerPolygons) in groups.enumerated() {
            // Determine target count based on longest perimeter
            let maxPerimeter = layerPolygons.polygons.map(\.perimeter).max()!

            let targetCount = environment.segmentation.segmentCount(length: maxPerimeter)
            var newPolygons = SimplePolygonList(layerPolygons.polygons.map {
                $0.resampled(count: targetCount)
            })

            // Align by minimizing total distance between consecutive layers
            newPolygons.alignOffsets()
            groups[index] = newPolygons
        }

        return mesh(for: groups, layerLevels: treeLayers.map(\.0))
    }

    // Takes a list of polygon trees representing each layer. Returns a list of polygon lists, each list representing the matching polygons from each layer
    func buildPolygonGroups(layerTrees: [PolygonTree]) -> [SimplePolygonList] {
        var groups = [SimplePolygonList]()
        if layerTrees[0].polygon.vertices.isEmpty == false {
            groups.append(SimplePolygonList(layerTrees.map(\.polygon)))
        }

        let childrenPerLayer = layerTrees.map(\.children)

        if childrenPerLayer.count > 0 {
            var remainingChildren = childrenPerLayer

            while !remainingChildren[0].isEmpty {
                // Take the first polygon tree of the first layer and treat it as the target
                let prototype = remainingChildren.first!.first!
                remainingChildren[0].remove(at: 0)

                // Filter each of the layers for polygons matching the topology of the target tree
                let candidatesPerLayer = remainingChildren.dropFirst().map {
                    $0.enumerated().filter { $1.matchesTopology(of: prototype) }
                }

                // Each layer has to have at least one matching polygon tree, otherwise the input is invalid
                precondition(candidatesPerLayer.allSatisfy({ $0.isEmpty == false }), "No topology match")

                // Go through the candidates layer by layer and find the one that is nearest the pick for the previous layer
                // and remove that one from remainingChildren so it's not included in the next pass
                var chosenTrees = [prototype]
                for (layerIndexMinusOne, candidates) in candidatesPerLayer.enumerated() {
                    let previousCentroid = chosenTrees.last!.polygon.centroid
                    let candidatesWithDistances = candidates.map { index, tree in
                        (index, tree, tree.polygon.centroid.distance(to: previousCentroid))
                    }
                    let (winnerIndex, winnerTree, _) = candidatesWithDistances.min(by: { $0.2 < $1.2 })!
                    remainingChildren[layerIndexMinusOne + 1].remove(at: winnerIndex)
                    chosenTrees.append(winnerTree)
                }

                // Recursively call buildPolygonGroups to build matching polygons for the chosen trees
                let childGroups = buildPolygonGroups(layerTrees: chosenTrees)
                groups.append(contentsOf: childGroups)
            }
        }
        return groups
    }

    func mesh(for polygonGroups: [SimplePolygonList], layerLevels: [Double]) -> Mesh {
        struct Vertex: Hashable {
            let polygonIndex: Int
            let layerIndex: Int
            let pointIndex: Int
        }

        let sideFaces = polygonGroups.enumerated().flatMap { polygonIndex, group in
            (0..<(group.count - 1)).flatMap { layerIndex1 in
                let layerIndex2 = layerIndex1 + 1
                return (0..<group[0].count).wrappedPairs().flatMap { pointIndex1, pointIndex2 in [
                    [
                        Vertex(polygonIndex: polygonIndex, layerIndex: layerIndex1, pointIndex: pointIndex2),
                        Vertex(polygonIndex: polygonIndex, layerIndex: layerIndex2, pointIndex: pointIndex2),
                        Vertex(polygonIndex: polygonIndex, layerIndex: layerIndex2, pointIndex: pointIndex1),
                    ],[
                        Vertex(polygonIndex: polygonIndex, layerIndex: layerIndex2, pointIndex: pointIndex1),
                        Vertex(polygonIndex: polygonIndex, layerIndex: layerIndex1, pointIndex: pointIndex1),
                        Vertex(polygonIndex: polygonIndex, layerIndex: layerIndex1, pointIndex: pointIndex2),
                    ]
                ]}
            }
        }

        let bottomPolygons = SimplePolygonList(polygonGroups.map { $0[0] })
        let bottomFaces = bottomPolygons.triangulate().map { a, b, c in [
            Vertex(polygonIndex: c.polygon, layerIndex: 0, pointIndex: c.vertex),
            Vertex(polygonIndex: b.polygon, layerIndex: 0, pointIndex: b.vertex),
            Vertex(polygonIndex: a.polygon, layerIndex: 0, pointIndex: a.vertex),
        ]}

        let topLayerIndex = layerLevels.count - 1
        let topPolygons = SimplePolygonList(polygonGroups.map { $0[topLayerIndex] })
        let topFaces = topPolygons.triangulate().map { a, b, c in [
            Vertex(polygonIndex: a.polygon, layerIndex: topLayerIndex, pointIndex: a.vertex),
            Vertex(polygonIndex: b.polygon, layerIndex: topLayerIndex, pointIndex: b.vertex),
            Vertex(polygonIndex: c.polygon, layerIndex: topLayerIndex, pointIndex: c.vertex),
        ]}

        return Mesh(faces: sideFaces + bottomFaces + topFaces) { vertex in
            let flatPoint = polygonGroups[vertex.polygonIndex][vertex.layerIndex][vertex.pointIndex]
            return Vector3D(flatPoint, z: layerLevels[vertex.layerIndex])
        }
    }
}
