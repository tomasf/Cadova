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

        // `frames` is ordered by distance, so the corner frames within it are too. Collecting their
        // indices once turns "is there a corner inside this span?" into a binary search over a handful
        // of entries. The subdivision below asks that question at every node of its recursion, and on
        // a smooth path the answer is always no, which used to mean rescanning the whole frame array
        // every time.
        let cornerIndices = frames.indices.filter { frames[$0].miterStretch != nil }

        func transform(atDistance distance: Double) -> Transform3D {
            curve.exactFrame(atDistance: distance, in: frames, reference: reference, target: sweepTarget).transform
        }

        /// The index, within `cornerIndices`, of the first corner frame lying strictly between two
        /// distances along the path, or `nil` if that stretch of path is smooth.
        func firstCorner(in searchRange: Range<Int>, between start: Double, and end: Double) -> Int? {
            var low = searchRange.lowerBound
            var high = searchRange.upperBound
            while low < high {
                let middle = (low + high) / 2
                if frames[cornerIndices[middle]].distance > start {
                    high = middle
                } else {
                    low = middle + 1
                }
            }
            guard low < searchRange.upperBound, frames[cornerIndices[low]].distance < end else { return nil }
            return low
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

                    case .adaptive(let minAngle, let minSize):
                        var results: [(polygon: SimplePolygon, transform: Transform3D)] = []
                        let sectionSpan = section1.distance - section0.distance
                        let maximumDeviation = Segmentation.surfaceDeviation(minAngle: minAngle, minSize: minSize)
                        // A backstop against a shaping function with a genuine discontinuity in it,
                        // which bisection can never resolve. The deviation test bottoms out long
                        // before this on anything continuous.
                        let maximumSubdivisionDepth = 32

                        func exactFrame(at fraction: Double) -> ParametricCurveFrame {
                            let distance = section0.distance + sectionSpan * fraction
                            return curve.exactFrame(atDistance: distance, in: frames, reference: reference, target: sweepTarget)
                        }

                        /// A ring on a smooth stretch of path, placed by the path's own frame there.
                        func regularSample(at fraction: Double) -> RingSample {
                            let distance = section0.distance + sectionSpan * fraction
                            return RingSample(
                                polygon: lower.blended(with: upper, t: function(fraction)),
                                transform: transform(atDistance: distance)
                            )
                        }

                        // A genuine sharp corner in the path is an irreducible discontinuity in the
                        // path tangent: transforms on either side never converge to each other by
                        // ordinary bisection. Split exactly at the miter frame, but interpolate the
                        // surrounding frames' orientation and miter stretch toward that frame. This
                        // keeps the loft surface continuous instead of creating a short, separate-looking
                        // patch around the corner.
                        func interpolatedSample(
                            at fraction: Double,
                            from start: ParametricCurveFrame,
                            to end: ParametricCurveFrame,
                            over range: Range<Double>
                        ) -> RingSample {
                            let frame = exactFrame(at: fraction)
                            let span = range.upperBound - range.lowerBound
                            let interpolation = span > 1e-12 ? (fraction - range.lowerBound) / span : 0
                            return RingSample(
                                polygon: lower.blended(with: upper, t: function(fraction)),
                                transform: start.interpolated(
                                    to: end,
                                    factor: interpolation,
                                    distance: frame.distance,
                                    point: frame.point,
                                    t: frame.t
                                ).transform
                            )
                        }

                        /// Bisects a smooth span until the surface across it is flat enough to be left
                        /// as a single band, emitting the lower bound of every span that survives.
                        ///
                        /// The test is a sagitta: build the interior rings both ways — the true
                        /// interpolated ring, and where an unsubdivided band between the two end rings
                        /// would put it — and keep splitting only while they disagree by more than the
                        /// deviation budget. Linear shaping along a straight path makes the two agree
                        /// exactly, which is why such a loft now stops at its two section rings.
                        ///
                        /// Three interior rings are checked, not just the midpoint. Shaping functions
                        /// that are symmetric about (0.5, 0.5) — `.smoothstep`, `.sine`, `.easeInOut`,
                        /// `.smootherstep` — pass exactly through the midpoint of their own chord, so a
                        /// midpoint-only test measures no error for them and would flatten the entire
                        /// S-curve into one band. The quarter points see the bulge, and they aren't
                        /// extra work: each becomes the midpoint of one of the two halves.
                        func subdivideSpan(
                            range: Range<Double>,
                            start: RingSample,
                            end: RingSample,
                            middle: RingSample,
                            depth: Int,
                            skipLowerBound: Bool,
                            sample: (Double) -> RingSample
                        ) {
                            let quarter = sample((range.lowerBound + range.mid) / 2)
                            let threeQuarters = sample((range.mid + range.upperBound) / 2)
                            let bandLength = start.separation(from: end)

                            // Warp is a two-directional error, so it is only worth acting on while the
                            // band is still longer than the rings' own edges. Below that the triangles
                            // are already more elongated along the path than around the ring, the
                            // surface error is dominated by the ring's own resolution, and splitting
                            // again refines the finer of the two directions for nothing. This also
                            // keeps the criterion from chasing a hand-built, deliberately coarse ring
                            // to absurd depth.
                            let warp = bandLength > start.maximumEdgeLength ? start.warp(across: end) : 0

                            let deviation = max(
                                quarter.deviation(fromChordBetween: start, and: end, at: 0.25),
                                middle.deviation(fromChordBetween: start, and: end, at: 0.5),
                                threeQuarters.deviation(fromChordBetween: start, and: end, at: 0.75),
                                warp
                            )

                            // Bisection stops on three counts: the band is already accurate enough;
                            // the two end rings are themselves closer together than the error being
                            // controlled, so nothing between them can be resolved and splitting
                            // further would only emit rings on top of each other; or the recursion
                            // has gone absurdly deep, which only a discontinuous shaping function
                            // can cause.
                            if deviation > maximumDeviation,
                               bandLength > maximumDeviation,
                               depth < maximumSubdivisionDepth {
                                subdivideSpan(
                                    range: range.lowerBound..<range.mid,
                                    start: start, end: middle, middle: quarter,
                                    depth: depth + 1, skipLowerBound: skipLowerBound, sample: sample
                                )
                                subdivideSpan(
                                    range: range.mid..<range.upperBound,
                                    start: middle, end: end, middle: threeQuarters,
                                    depth: depth + 1, skipLowerBound: false, sample: sample
                                )
                            } else if !skipLowerBound {
                                results.append((start.polygon, start.transform))
                            }
                        }

                        /// Splits the span at each sharp corner it contains and hands the smooth
                        /// stretches between them to `subdivideSpan`. End rings are threaded through
                        /// rather than recomputed: every ring is built exactly once.
                        func subdivide(
                            range: Range<Double>,
                            cornerSearchRange: Range<Int>,
                            start: RingSample,
                            end: RingSample,
                            skipLowerBound: Bool
                        ) {
                            let distanceStart = section0.distance + sectionSpan * range.lowerBound
                            let distanceEnd = section0.distance + sectionSpan * range.upperBound

                            guard let cornerSlot = firstCorner(
                                in: cornerSearchRange, between: distanceStart, and: distanceEnd
                            ) else {
                                subdivideSpan(
                                    range: range, start: start, end: end, middle: regularSample(at: range.mid),
                                    depth: 0, skipLowerBound: skipLowerBound, sample: regularSample
                                )
                                return
                            }

                            let corner = frames[cornerIndices[cornerSlot]]
                            let cornerFraction = (corner.distance - section0.distance) / sectionSpan
                            let cornerSample = RingSample(
                                polygon: lower.blended(with: upper, t: function(cornerFraction)),
                                transform: corner.transform
                            )

                            if cornerFraction > range.lowerBound + 1e-12 {
                                let leadIn = range.lowerBound..<cornerFraction
                                let startFrame = exactFrame(at: range.lowerBound)
                                func leadInSample(_ fraction: Double) -> RingSample {
                                    interpolatedSample(at: fraction, from: startFrame, to: corner, over: leadIn)
                                }
                                subdivideSpan(
                                    range: leadIn, start: start, end: cornerSample,
                                    middle: leadInSample(leadIn.mid),
                                    depth: 0, skipLowerBound: skipLowerBound, sample: leadInSample
                                )
                            }

                            results.append((cornerSample.polygon, cornerSample.transform))

                            if cornerFraction < range.upperBound - 1e-12 {
                                let remaining = (cornerSlot + 1)..<cornerSearchRange.upperBound
                                if firstCorner(in: remaining, between: corner.distance, and: distanceEnd) != nil {
                                    subdivide(
                                        range: cornerFraction..<range.upperBound,
                                        cornerSearchRange: remaining,
                                        start: cornerSample, end: end, skipLowerBound: true
                                    )
                                } else {
                                    let leadOut = cornerFraction..<range.upperBound
                                    let endFrame = exactFrame(at: range.upperBound)
                                    func leadOutSample(_ fraction: Double) -> RingSample {
                                        interpolatedSample(at: fraction, from: corner, to: endFrame, over: leadOut)
                                    }
                                    subdivideSpan(
                                        range: leadOut, start: cornerSample, end: end,
                                        middle: leadOutSample(leadOut.mid),
                                        depth: 0, skipLowerBound: true, sample: leadOutSample
                                    )
                                }
                            }
                        }

                        subdivide(
                            range: 0..<1,
                            cornerSearchRange: cornerIndices.indices,
                            start: RingSample(polygon: lower.blended(with: upper, t: function(0)), transform: transform0),
                            end: RingSample(polygon: lower.blended(with: upper, t: function(1)), transform: transform1),
                            skipLowerBound: true
                        )
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

/// A candidate cross-section ring: the blended 2D polygon, and the frame transform that places it in
/// space. Its world-space vertices are computed once, when the ring is built, so that the subdivision
/// test doesn't reapply two 4×4 transforms to every vertex at every level of the recursion, and so
/// that a ring built as one span's interior sample can be reused as an end ring of the span's halves.
fileprivate struct RingSample {
    let polygon: SimplePolygon
    let transform: Transform3D
    let worldVertices: [Vector3D]
    /// The longest edge of this ring, in world space — the resolution the mesh already has in the
    /// around-the-ring direction, which bounds how much accuracy refining the other direction can buy.
    let maximumEdgeLength: Double

    init(polygon: SimplePolygon, transform: Transform3D) {
        let worldVertices = polygon.vertices(transformedBy: transform)
        self.polygon = polygon
        self.transform = transform
        self.worldVertices = worldVertices
        self.maximumEdgeLength = worldVertices.cyclicPairs().reduce(0) { max($0, ($1.1 - $1.0).magnitude) }
    }

    /// How far this ring sits from where a single unsubdivided band between `start` and `end` would
    /// put it, `fraction` of the way along that band, measured at its most displaced vertex.
    ///
    /// This is the sagitta of the loft's surface: exactly the fidelity that inserting a ring here
    /// would buy, and zero whenever the band already describes the surface perfectly.
    func deviation(fromChordBetween start: Self, and end: Self, at fraction: Double) -> Double {
        let count = min(worldVertices.count, start.worldVertices.count, end.worldVertices.count)
        var maximum = 0.0
        for index in 0..<count {
            let chordStart = start.worldVertices[index]
            let chord = chordStart + (end.worldVertices[index] - chordStart) * fraction
            maximum = max(maximum, (worldVertices[index] - chord).magnitude)
        }
        return maximum
    }

    /// The largest gap between the ruled surface a band to `other` stands for and the triangle strip
    /// the mesh will actually build across it.
    ///
    /// The chord test above cannot see this. The mesh joins corresponding vertices of the two rings,
    /// so every intermediate ring lies exactly on those rulings and reports no deviation at all — yet
    /// each pair of adjacent rulings bounds a quad that is generally not planar, and gets split into
    /// two triangles along a diagonal. At the quad's centre the true bilinear surface sits at
    /// ¼(A + B + C + D) while the two triangles meet at the midpoint of either diagonal, and the part
    /// of that offset normal to the quad is surface the mesh simply doesn't have. Only splitting the
    /// band shortens it — halving the band halves the warp — which is what makes one long, strongly
    /// sheared band genuinely worse than several short ones, however exactly ruled it is.
    func warp(across other: Self) -> Double {
        let count = min(worldVertices.count, other.worldVertices.count)
        guard count > 1 else { return 0 }

        var maximum = 0.0
        for index in 0..<count {
            let next = (index + 1) % count
            let a = worldVertices[index]
            let b = worldVertices[next]
            let c = other.worldVertices[next]
            let d = other.worldVertices[index]

            let normal = (c - a) × (d - b)
            let magnitude = normal.magnitude
            guard magnitude > 1e-12 else { continue }
            maximum = max(maximum, abs(((a + c - b - d) / 4) ⋅ (normal / magnitude)))
        }
        return maximum
    }

    /// How far apart two rings sit at their most separated vertex.
    func separation(from other: Self) -> Double {
        let count = min(worldVertices.count, other.worldVertices.count)
        var maximum = 0.0
        for index in 0..<count {
            maximum = max(maximum, (worldVertices[index] - other.worldVertices[index]).magnitude)
        }
        return maximum
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
