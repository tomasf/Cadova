import Foundation
import Manifold3D

internal extension Loft {
    struct ResamplingLayer {
        let z: Double
        let function: ShapingFunction
        let tree: PolygonTree
    }

    static func resampledLoft(resamplingLayers: [ResamplingLayer], in environment: EnvironmentValues) async -> any Geometry3D {
        var groups = buildPolygonGroups(layerTrees: resamplingLayers.map(\.tree))

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

        let interpolatedGroups = Self.interpolatePolygonGroups(for: groups, layers: resamplingLayers, environment: environment)
        return Mesh(polygonGroups: interpolatedGroups)
            .simplified()
    }

    // Takes a list of polygon trees representing each layer. Returns a list of polygon lists, each list representing
    // the matching polygons from each layer
    static func buildPolygonGroups(layerTrees: [PolygonTree]) -> [SimplePolygonList] {
        var groups = [SimplePolygonList]()
        if layerTrees[0].polygon.vertices.isEmpty == false {
            groups.append(SimplePolygonList(layerTrees.map(\.polygon)))
        }

        var remainingChildren = layerTrees.map(\.children)

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

            // Go through the candidates layer by layer and find the one that is nearest the pick for the previous
            // layer and remove that one from remainingChildren so it's not included in the next pass
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
        return groups
    }

    static func interpolatePolygonGroups(
        for polygonGroups: [SimplePolygonList],
        layers: [ResamplingLayer],
        environment: EnvironmentValues
    ) -> [(polygons: SimplePolygonList, zLevels: [Double])] {
        let segmentation = environment.segmentation
        var refinedGroups: [(polygons: SimplePolygonList, zLevels: [Double])] = []

        for polygons in polygonGroups {
            var newPolygons: [SimplePolygon] = [polygons[0]]
            var newZLevels: [Double] = [layers[0].z]

            for i in 1..<layers.count {
                let lower = polygons[i - 1]
                let upper = polygons[i]
                let layer0 = layers[i - 1]
                let layer1 = layers[i]
                let interpolatedLayers: [(polygon: SimplePolygon, z: Double)]

                switch segmentation {
                case .fixed(let count):
                    interpolatedLayers = (1..<count).map { j in
                        let t = Double(j) / Double(count)
                        let z = layer0.z + (layer1.z - layer0.z) * t
                        let polygon = lower.blended(with: upper, t: layer1.function(t))
                        return (polygon, z)
                    }

                case .adaptive(_, let minLength):
                    var results: [(polygon: SimplePolygon, z: Double)] = []

                    func subdivide(range: Range<Double>) {
                        let zStart = layer0.z + (layer1.z - layer0.z) * range.lowerBound
                        let zEnd = layer0.z + (layer1.z - layer0.z) * range.upperBound
                        let pStart = lower.blended(with: upper, t: layer1.function(range.lowerBound))
                        let pEnd = lower.blended(with: upper, t: layer1.function(range.upperBound))

                        if pStart.needsSubdivision(next: pEnd, z0: zStart, z1: zEnd, minLength: minLength) {
                            let tMid = range.mid
                            subdivide(range: range.lowerBound..<tMid)
                            subdivide(range: tMid..<range.upperBound)
                        } else {
                            results.append((pStart, zStart))
                        }
                    }

                    subdivide(range: 0..<1)
                    interpolatedLayers = results
                }

                newPolygons.append(contentsOf: interpolatedLayers.map(\.polygon))
                newZLevels.append(contentsOf: interpolatedLayers.map(\.z))
                newPolygons.append(upper)
                newZLevels.append(layer1.z)
            }

            refinedGroups.append((SimplePolygonList(newPolygons), newZLevels))
        }

        return refinedGroups
    }
}

fileprivate extension SimplePolygon {
    func needsSubdivision(next: SimplePolygon, z0: Double, z1: Double, minLength: Double) -> Bool {
        (0..<count).contains {
            (Vector3D(next[$0], z: z1) - Vector3D(self[$0], z: z0)).magnitude > minLength
        }
    }
}

fileprivate extension Mesh {
    init(polygonGroups: [(polygons: SimplePolygonList, zLevels: [Double])]) {
        struct Vertex: Hashable {
            let polygonGroupIndex: Int
            let layerIndex: Int
            let pointIndex: Int
        }

        let sideFaces = polygonGroups.map(\.0).enumerated().flatMap { polygonIndex, group in
            (0..<(group.count - 1)).flatMap { layerIndex1 in
                let layerIndex2 = layerIndex1 + 1
                return (0..<group[0].count).wrappedPairs().flatMap { pointIndex1, pointIndex2 in [
                    [
                        Vertex(polygonGroupIndex: polygonIndex, layerIndex: layerIndex1, pointIndex: pointIndex2),
                        Vertex(polygonGroupIndex: polygonIndex, layerIndex: layerIndex2, pointIndex: pointIndex2),
                        Vertex(polygonGroupIndex: polygonIndex, layerIndex: layerIndex2, pointIndex: pointIndex1),
                    ],[
                        Vertex(polygonGroupIndex: polygonIndex, layerIndex: layerIndex2, pointIndex: pointIndex1),
                        Vertex(polygonGroupIndex: polygonIndex, layerIndex: layerIndex1, pointIndex: pointIndex1),
                        Vertex(polygonGroupIndex: polygonIndex, layerIndex: layerIndex1, pointIndex: pointIndex2),
                    ]
                ]}
            }
        }

        let bottomPolygons = SimplePolygonList(polygonGroups.map { $0.polygons[0] })
        let bottomFaces = bottomPolygons.triangulated().map { a, b, c in [
            Vertex(polygonGroupIndex: c.polygon, layerIndex: 0, pointIndex: c.vertex),
            Vertex(polygonGroupIndex: b.polygon, layerIndex: 0, pointIndex: b.vertex),
            Vertex(polygonGroupIndex: a.polygon, layerIndex: 0, pointIndex: a.vertex),
        ]}

        let topPolygons = SimplePolygonList(polygonGroups.map { $0.polygons[$0.polygons.count - 1] })
        let topFaces = topPolygons.triangulated().map { a, b, c in [
            Vertex(polygonGroupIndex: a.polygon, layerIndex: polygonGroups[a.polygon].polygons.count - 1, pointIndex: a.vertex),
            Vertex(polygonGroupIndex: b.polygon, layerIndex: polygonGroups[b.polygon].polygons.count - 1, pointIndex: b.vertex),
            Vertex(polygonGroupIndex: c.polygon, layerIndex: polygonGroups[c.polygon].polygons.count - 1, pointIndex: c.vertex),
        ]}

        self.init(faces: sideFaces + bottomFaces + topFaces) { vertex in
            let flatPoint = polygonGroups[vertex.polygonGroupIndex].polygons[vertex.layerIndex][vertex.pointIndex]
            return Vector3D(flatPoint, z: polygonGroups[vertex.polygonGroupIndex].zLevels[vertex.layerIndex])
        }
    }
}
