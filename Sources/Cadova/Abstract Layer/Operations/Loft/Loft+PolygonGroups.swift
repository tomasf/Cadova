import Foundation

internal extension Loft {
    // Takes a list of polygon trees representing each section. Returns a list of polygon lists, each list representing
    // the matching polygons from each section
    static func buildPolygonGroups(sectionTrees: [PolygonTree]) -> [SimplePolygonList] {
        var groups = [SimplePolygonList]()
        if sectionTrees[0].polygon.vertices.isEmpty == false {
            groups.append(SimplePolygonList(sectionTrees.map(\.polygon)))
        }

        var remainingChildren = sectionTrees.map(\.children)
        let childCounts = remainingChildren.map(\.count)
        precondition(
            childCounts.allSatisfy { $0 == childCounts[0] },
            "Loft sections must have the same number of islands. Found: \(childCounts)"
        )

        while !remainingChildren[0].isEmpty {
            // Take the first polygon tree of the first section and treat it as the target
            let prototype = remainingChildren.first!.first!
            remainingChildren[0].remove(at: 0)

            // Filter each of the sections for polygons matching the topology of the target tree
            let candidatesPerSection = remainingChildren.dropFirst().map {
                $0.enumerated().filter { $1.matchesTopology(of: prototype) }
            }

            // Each section has to have at least one matching polygon tree, otherwise the input is invalid
            precondition(candidatesPerSection.allSatisfy({ $0.isEmpty == false }), "No topology match")

            // Go through the candidates section by section and find the one that is nearest the pick for the previous
            // section and remove that one from remainingChildren so it's not included in the next pass
            var chosenTrees = [prototype]
            for (sectionIndexMinusOne, candidates) in candidatesPerSection.enumerated() {
                let previousCentroid = chosenTrees.last!.polygon.centroid
                let candidatesWithDistances = candidates.map { index, tree in
                    (index, tree, tree.polygon.centroid.distance(to: previousCentroid))
                }
                let (winnerIndex, winnerTree, _) = candidatesWithDistances.min(by: { $0.2 < $1.2 })!
                remainingChildren[sectionIndexMinusOne + 1].remove(at: winnerIndex)
                chosenTrees.append(winnerTree)
            }

            // Recursively call buildPolygonGroups to build matching polygons for the chosen trees
            let childGroups = buildPolygonGroups(sectionTrees: chosenTrees)
            groups.append(contentsOf: childGroups)
        }
        return groups
    }

    static func interpolatePolygonGroups(
        for polygonGroups: [SimplePolygonList],
        sections: [ResamplingSection],
        frames: [ParametricCurveFrame],
        environment: EnvironmentValues
    ) -> [(polygons: SimplePolygonList, transforms: [Transform3D])] {
        let segmentation = environment.scaledSegmentation
        var refinedGroups: [(polygons: SimplePolygonList, transforms: [Transform3D])] = []

        func transform(atDistance distance: Double) -> Transform3D {
            frames.binarySearchInterpolate(target: distance, key: \.distance, result: \.transform)
        }

        for polygons in polygonGroups {
            var newPolygons: [SimplePolygon] = [polygons[0]]
            var newTransforms: [Transform3D] = [transform(atDistance: sections[0].distance)]

            for i in 1..<sections.count {
                let lower = polygons[i - 1]
                let upper = polygons[i]
                let section0 = sections[i - 1]
                let section1 = sections[i]
                let interpolatedSections: [(polygon: SimplePolygon, transform: Transform3D)]
                let transform0 = transform(atDistance: section0.distance)
                let transform1 = transform(atDistance: section1.distance)

                // Optimization: When shapes are identical AND the path's orientation hasn't changed
                // between the two sections, no intermediate sections are needed. Blending identical
                // shapes under an unchanging orientation produces the same result regardless of the
                // shaping function, so all intermediate sections would be duplicates, and the mesh
                // faces between sections can be planar rectangles (split into triangles). Two sections
                // always have different translations (they're at different distances along the path),
                // so only the rotation is compared here; if it differs (e.g. the path twists between
                // these sections), a single straight connection would cut across the twist, so
                // subdivision must still run even though the 2D shape itself is unchanged.
                let canSkipIntermediate = lower == upper && transform0.hasEqualOrientation(to: transform1)

                // In interpolated segments, all sections have a shaping function
                let function = section1.shapingFunction ?? .linear

                if canSkipIntermediate {
                    interpolatedSections = []
                } else {
                    switch segmentation {
                    case .fixed(let count):
                        interpolatedSections = (1..<count).map { j in
                            let t = Double(j) / Double(count)
                            let distance = section0.distance + (section1.distance - section0.distance) * t
                            let polygon = lower.blended(with: upper, t: function(t))
                            return (polygon, transform(atDistance: distance))
                        }

                    case .adaptive(_, let minLength):
                        var results: [(polygon: SimplePolygon, transform: Transform3D)] = []

                        func subdivide(range: Range<Double>) {
                            let distanceStart = section0.distance + (section1.distance - section0.distance) * range.lowerBound
                            let distanceEnd = section0.distance + (section1.distance - section0.distance) * range.upperBound
                            let transformStart = transform(atDistance: distanceStart)
                            let transformEnd = transform(atDistance: distanceEnd)
                            let pStart = lower.blended(with: upper, t: function(range.lowerBound))
                            let pEnd = lower.blended(with: upper, t: function(range.upperBound))

                            if pStart.needsSubdivision(next: pEnd, transform0: transformStart, transform1: transformEnd, minLength: minLength) {
                                let tMid = range.mid
                                subdivide(range: range.lowerBound..<tMid)
                                subdivide(range: tMid..<range.upperBound)
                            } else {
                                results.append((pStart, transformStart))
                            }
                        }

                        subdivide(range: 0..<1)
                        interpolatedSections = results
                    }
                }

                newPolygons.append(contentsOf: interpolatedSections.map(\.polygon))
                newTransforms.append(contentsOf: interpolatedSections.map(\.transform))
                newPolygons.append(upper)
                newTransforms.append(transform1)
            }

            refinedGroups.append((SimplePolygonList(newPolygons), newTransforms))
        }

        return refinedGroups
    }
}

fileprivate extension Transform3D {
    // Compares only the rotational part of two transforms, ignoring translation. Two sections along a
    // path always sit at different positions, so comparing full transforms (translation included) would
    // never consider them equal; what actually matters for the "skip intermediate subdivision" optimization
    // is whether the frame's orientation is unchanged between them.
    func hasEqualOrientation(to other: Transform3D) -> Bool {
        let relative = inverse.concatenated(with: other)
        let origin = relative.apply(to: .zero)
        let dx = relative.apply(to: Vector3D(x: 1)) - origin - Vector3D(x: 1)
        let dy = relative.apply(to: Vector3D(y: 1)) - origin - Vector3D(y: 1)
        return dx.magnitude < 1e-9 && dy.magnitude < 1e-9
    }
}

fileprivate extension SimplePolygon {
    func needsSubdivision(next: SimplePolygon, transform0: Transform3D, transform1: Transform3D, minLength: Double) -> Bool {
        (0..<count).contains {
            (transform1.apply(to: Vector3D(next[$0], z: 0)) - transform0.apply(to: Vector3D(self[$0], z: 0))).magnitude > minLength
        }
    }
}
