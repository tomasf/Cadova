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
}
