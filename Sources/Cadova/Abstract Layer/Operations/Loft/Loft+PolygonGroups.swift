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
        curve: any ParametricCurve<Vector3D>,
        reference: Direction2D,
        target sweepTarget: ReferenceTarget,
        environment: EnvironmentValues
    ) -> [(polygons: SimplePolygonList, transforms: [Transform3D])] {
        let segmentation = environment.scaledSegmentation
        var refinedGroups: [(polygons: SimplePolygonList, transforms: [Transform3D])] = []

        func transform(atDistance distance: Double) -> Transform3D {
            curve.exactFrame(atDistance: distance, in: frames, reference: reference, target: sweepTarget).transform
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
                        let sectionSpan = section1.distance - section0.distance

                        // A genuine sharp corner in the path (e.g. two sub-curves meeting at a real
                        // angle) is an irreducible discontinuity in orientation: transforms on either
                        // side never converge to each other no matter how far this bisects, since a
                        // mitered joint's own frame legitimately differs from its neighbors by design
                        // (see ParametricCurveFrame.miterCorners). Blindly bisecting toward it would
                        // recurse forever (or, capped, land many independent branches on slightly
                        // different near-corner positions — visible as a cluster of stray sliver faces
                        // instead of one clean seam). Instead, explicitly detect a corner frame inside
                        // the current range, split exactly there, and insert its own precomputed
                        // (correctly mitered) frame directly — then recurse only on the two sub-ranges
                        // on either side, each of which is now genuinely smooth and converges normally.
                        // Corners are found by searching a shrinking *index* range into `frames`, not by
                        // re-deriving distance bounds from `range` and comparing floating-point distances —
                        // the latter can drift enough on the recursive round-trip (fraction → distance →
                        // fraction) for the same corner to match again in a sub-range that's supposed to
                        // exclude it, causing runaway/duplicate insertion at exactly the corner. Index-based
                        // exclusion makes re-matching the same corner structurally impossible.
                        // Every leaf below emits only its range's lower bound; the upper bound is picked up
                        // either by the next leaf's lower bound or, for the very last one, by the caller's own
                        // `upper`/`transform1` append. `skipLowerBound` suppresses that for ranges whose lower
                        // bound was already emitted: the full section range starts with the previous section's
                        // ring already in `newPolygons`, and the subrange immediately after a corner starts
                        // with the explicitly inserted miter ring below. Without this, the mesh gets a
                        // zero-height band between duplicate or nearly-duplicate rings.
                        func regularSection(at fraction: Double) -> (polygon: SimplePolygon, transform: Transform3D) {
                            let distance = section0.distance + sectionSpan * fraction
                            return (
                                lower.blended(with: upper, t: function(fraction)),
                                transform(atDistance: distance)
                            )
                        }

                        func appendRegularSection(at fraction: Double) {
                            let section = regularSection(at: fraction)
                            results.append(section)
                        }

                        func appendLowerCut(at fraction: Double, before cornerFraction: Double, range: Range<Double>, skipLowerBound: Bool) {
                            if fraction > range.lowerBound + 1e-12, fraction < cornerFraction - 1e-12 {
                                appendRegularSection(at: fraction)
                            } else if !skipLowerBound {
                                appendRegularSection(at: range.lowerBound)
                            }
                        }

                        func appendUpperCut(at fraction: Double, after cornerFraction: Double, range: Range<Double>) {
                            if fraction > cornerFraction + 1e-12, fraction < range.upperBound - 1e-12 {
                                appendRegularSection(at: fraction)
                            }
                        }

                        func subdivide(range: Range<Double>, frameSearchRange: Range<Int>, depth: Int = 0, skipLowerBound: Bool = false) {
                            let distanceStart = section0.distance + sectionSpan * range.lowerBound
                            let distanceEnd = section0.distance + sectionSpan * range.upperBound

                            if let cornerIndex = frames[frameSearchRange].firstIndex(where: {
                                $0.miterStretch != nil && $0.distance > distanceStart && $0.distance < distanceEnd
                            }) {
                                let corner = frames[cornerIndex]
                                let cornerFraction = (corner.distance - section0.distance) / sectionSpan
                                let cornerPolygon = lower.blended(with: upper, t: function(cornerFraction))
                                let cornerPoints = cornerPolygon.map {
                                    corner.transform.apply(to: Vector3D($0, z: 0))
                                }
                                let incomingDirection = (corner.point - frames[cornerIndex - 1].point).normalized
                                let outgoingDirection = (frames[cornerIndex + 1].point - corner.point).normalized
                                let lowerCutDistance = cornerPoints.map {
                                    corner.distance + (($0 - corner.point) ⋅ incomingDirection)
                                }.min()!
                                let upperCutDistance = cornerPoints.map {
                                    corner.distance + (($0 - corner.point) ⋅ outgoingDirection)
                                }.max()!
                                let lowerCutFraction = ((lowerCutDistance - section0.distance) / sectionSpan)
                                    .clamped(to: range.lowerBound...cornerFraction)
                                let upperCutFraction = ((upperCutDistance - section0.distance) / sectionSpan)
                                    .clamped(to: cornerFraction...range.upperBound)

                                if lowerCutFraction > range.lowerBound + 1e-12 {
                                    subdivide(range: range.lowerBound..<lowerCutFraction, frameSearchRange: frameSearchRange.lowerBound..<cornerIndex, depth: depth + 1, skipLowerBound: skipLowerBound)
                                }
                                appendLowerCut(at: lowerCutFraction, before: cornerFraction, range: range, skipLowerBound: skipLowerBound)
                                results.append((lower.blended(with: upper, t: function(cornerFraction)), corner.transform))
                                appendUpperCut(at: upperCutFraction, after: cornerFraction, range: range)
                                if upperCutFraction < range.upperBound - 1e-12 {
                                    subdivide(range: upperCutFraction..<range.upperBound, frameSearchRange: (cornerIndex + 1)..<frameSearchRange.upperBound, depth: depth + 1, skipLowerBound: true)
                                }
                                return
                            }

                            let transformStart = transform(atDistance: distanceStart)
                            let transformEnd = transform(atDistance: distanceEnd)
                            let pStart = lower.blended(with: upper, t: function(range.lowerBound))
                            let pEnd = lower.blended(with: upper, t: function(range.upperBound))

                            if distanceEnd - distanceStart > minLength,
                               depth < 32,
                               pStart.needsSubdivision(next: pEnd, transform0: transformStart, transform1: transformEnd, minLength: minLength) {
                                let tMid = range.mid
                                subdivide(range: range.lowerBound..<tMid, frameSearchRange: frameSearchRange, depth: depth + 1, skipLowerBound: skipLowerBound)
                                subdivide(range: tMid..<range.upperBound, frameSearchRange: frameSearchRange, depth: depth + 1)
                            } else if !skipLowerBound {
                                results.append((pStart, transformStart))
                            }
                        }

                        subdivide(range: 0..<1, frameSearchRange: frames.indices, skipLowerBound: true)
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
