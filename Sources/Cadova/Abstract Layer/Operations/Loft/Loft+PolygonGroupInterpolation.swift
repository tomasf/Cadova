import Foundation

internal extension Loft {
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

                        // A genuine sharp corner in the path is an irreducible discontinuity in the
                        // path tangent: transforms on either side never converge to each other by
                        // ordinary bisection. Split exactly at the miter frame, but interpolate the
                        // surrounding frames' orientation and miter stretch toward that frame. This
                        // keeps the loft surface continuous instead of creating a short, separate-looking
                        // patch around the corner.
                        func regularSection(at fraction: Double) -> (polygon: SimplePolygon, transform: Transform3D) {
                            let distance = section0.distance + sectionSpan * fraction
                            return (
                                lower.blended(with: upper, t: function(fraction)),
                                transform(atDistance: distance)
                            )
                        }

                        func exactFrame(at fraction: Double) -> ParametricCurveFrame {
                            let distance = section0.distance + sectionSpan * fraction
                            return curve.exactFrame(atDistance: distance, in: frames, reference: reference, target: sweepTarget)
                        }

                        func interpolatedSection(at fraction: Double, from start: ParametricCurveFrame, to end: ParametricCurveFrame, over range: Range<Double>) -> (polygon: SimplePolygon, transform: Transform3D) {
                            let frame = exactFrame(at: fraction)
                            let span = range.upperBound - range.lowerBound
                            let interpolation = span > 1e-12 ? (fraction - range.lowerBound) / span : 0
                            return (
                                lower.blended(with: upper, t: function(fraction)),
                                start.interpolated(
                                    to: end,
                                    factor: interpolation,
                                    distance: frame.distance,
                                    point: frame.point,
                                    t: frame.t
                                ).transform
                            )
                        }

                        func subdivideSmooth(
                            range: Range<Double>,
                            interpolationRange: Range<Double>,
                            start: ParametricCurveFrame,
                            end: ParametricCurveFrame,
                            depth: Int = 0,
                            skipLowerBound: Bool = false
                        ) {
                            let distanceStart = section0.distance + sectionSpan * range.lowerBound
                            let distanceEnd = section0.distance + sectionSpan * range.upperBound
                            let startSection = interpolatedSection(at: range.lowerBound, from: start, to: end, over: interpolationRange)
                            let endSection = interpolatedSection(at: range.upperBound, from: start, to: end, over: interpolationRange)

                            if distanceEnd - distanceStart > minLength,
                               depth < 32,
                               startSection.polygon.needsSubdivision(next: endSection.polygon, transform0: startSection.transform, transform1: endSection.transform, minLength: minLength) {
                                let tMid = range.mid
                                subdivideSmooth(range: range.lowerBound..<tMid, interpolationRange: interpolationRange, start: start, end: end, depth: depth + 1, skipLowerBound: skipLowerBound)
                                subdivideSmooth(range: tMid..<range.upperBound, interpolationRange: interpolationRange, start: start, end: end, depth: depth + 1)
                            } else if !skipLowerBound {
                                results.append(startSection)
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

                                if cornerFraction > range.lowerBound + 1e-12 {
                                    subdivideSmooth(
                                        range: range.lowerBound..<cornerFraction,
                                        interpolationRange: range.lowerBound..<cornerFraction,
                                        start: exactFrame(at: range.lowerBound),
                                        end: corner,
                                        depth: depth + 1,
                                        skipLowerBound: skipLowerBound
                                    )
                                }
                                results.append((lower.blended(with: upper, t: function(cornerFraction)), corner.transform))
                                if cornerFraction < range.upperBound - 1e-12 {
                                    let remainingFrameSearchRange = (cornerIndex + 1)..<frameSearchRange.upperBound
                                    if remainingFrameSearchRange.contains(where: {
                                        frames[$0].miterStretch != nil && frames[$0].distance > corner.distance && frames[$0].distance < distanceEnd
                                    }) {
                                        subdivide(
                                            range: cornerFraction..<range.upperBound,
                                            frameSearchRange: remainingFrameSearchRange,
                                            depth: depth + 1,
                                            skipLowerBound: true
                                        )
                                    } else {
                                        subdivideSmooth(
                                            range: cornerFraction..<range.upperBound,
                                            interpolationRange: cornerFraction..<range.upperBound,
                                            start: corner,
                                            end: exactFrame(at: range.upperBound),
                                            depth: depth + 1,
                                            skipLowerBound: true
                                        )
                                    }
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
