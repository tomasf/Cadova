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

        // One probe lattice per section pair, shared by every polygon group. Its samples depend only
        // on the shaping function and the path, so building it inside the group loop would repeat
        // identical work for every hole and island a section has. It is built on demand because a
        // section pair whose shapes and orientation already match needs no subdivision at all, and so
        // never asks for one.
        var latticeCache: [Int: DeviationProbe.Lattice] = [:]
        func deviationLattice(forSectionPair index: Int) -> DeviationProbe.Lattice {
            if let cached = latticeCache[index] { return cached }
            let start = sections[index - 1].distance
            let span = sections[index].distance - start
            let pathSampleCount = frames.reduce(0) {
                $1.distance > start && $1.distance < start + span ? $0 + 1 : $0
            }
            let lattice = DeviationProbe.Lattice(
                shaping: (sections[index].shapingFunction ?? .linear).function,
                frames: frames,
                startDistance: start,
                span: span,
                count: segmentation.deviationProbeCount(pathLength: span, pathSampleCount: pathSampleCount)
            )
            latticeCache[index] = lattice
            return lattice
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

                        let probe = DeviationProbe(
                            lattice: deviationLattice(forSectionPair: i), lower: lower, upper: upper
                        )

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
                        /// Where the interior rings are measured matters as much as how. Three of them
                        /// sit at fixed fractions: the midpoint, which is where the span will be split
                        /// anyway, and the two quarter points, which cost nothing because each becomes
                        /// the midpoint of one half. Those three are not enough on their own. Shaping
                        /// functions symmetric about (0.5, 0.5), such as `.smoothstep`, `.sine`,
                        /// `.easeInOut` and `.smootherstep`, pass exactly through the midpoint of their
                        /// own chord, so a midpoint-only test reads no error for them at all, and any
                        /// fixed set of fractions can be cancelled the same way by a function whose
                        /// deviation vanishes at every one of them.
                        ///
                        /// A fourth ring closes that off. `DeviationProbe` searches a lattice far finer
                        /// than anything that will be built, without building anything, and says where
                        /// the surface is furthest from this band. The ring goes there. Nothing is
                        /// decided from the probe's estimate; it only chooses the spot, and the error is
                        /// then measured on a real ring exactly as the other three are.
                        func subdivideSpan(
                            range: Range<Double>,
                            start: RingSample,
                            end: RingSample,
                            middle: RingSample,
                            depth: Int,
                            skipLowerBound: Bool,
                            sample: (Double) -> RingSample
                        ) {
                            let spanWidth = range.upperBound - range.lowerBound
                            let quarterFraction = (range.lowerBound + range.mid) / 2
                            let threeQuartersFraction = (range.mid + range.upperBound) / 2
                            let quarter = sample(quarterFraction)
                            let threeQuarters = sample(threeQuartersFraction)
                            let bandLength = start.separation(from: end)

                            // The one ring whose position is chosen by the shape rather than fixed in
                            // advance. It is skipped when the probe finds nothing the three fixed
                            // fractions do not already cover, which is the usual case on a function
                            // that simply bulges one way.
                            var probedDeviation = 0.0
                            if spanWidth > 1e-12, let probedFraction = probe.worstFraction(
                                in: range, tested: [quarterFraction, range.mid, threeQuartersFraction]
                            ) {
                                probedDeviation = sample(probedFraction).deviation(
                                    fromChordBetween: start, and: end,
                                    at: (probedFraction - range.lowerBound) / spanWidth
                                )
                            }

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
                                probedDeviation,
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

/// A dense, precomputed picture of everything that can push a ring away from a straight band between
/// two sections, used to choose where the subdivision test should look.
///
/// The test that decides whether a band is accurate enough can only measure rings it actually builds,
/// and building a ring transforms every one of its vertices, so the test can only afford a few. Fixed
/// sample positions are not a safe way to spend them. Whatever fractions are chosen, a shaping
/// function whose deviation happens to vanish at all of them reads as perfectly flat, and the band is
/// never split. Sampling at a quarter, a half and three quarters is cancelled exactly by
/// `t + a·sin(4·2πt)` and by every other wave count that lines up with those three points, and adding
/// a fifth fixed position only moves the blind spot to a different wave count. No fixed set of
/// positions can be safe, because the function is free to have zeros wherever the set does.
///
/// So this stops guessing where to look and lets the shape say. Evaluating a shaping function is
/// scalar arithmetic, thousands of times cheaper than building a ring, and the path has already been
/// sampled into the frame array. This probe walks a lattice fine enough to resolve anything the
/// segmentation could draw, estimates how far each lattice point's ring would sit from the band
/// without building a single ring, and reports the worst point. The subdivision test then builds one
/// real ring there and measures it exactly.
///
/// The estimate itself does not need to be accurate, and nothing is decided from it. It only has to
/// point at roughly the right place, because the accuracy decision is still made by the exact
/// measurement in `RingSample.deviation(fromChordBetween:and:at:)` on a ring that really was built.
/// That leaves one limit, and it is a stated one rather than an accident of where three samples fell:
/// a bump narrower than a lattice step can still hide, and a lattice step is finer than the shortest
/// band this segmentation will ever emit, so a bump that narrow could not have been drawn either way.
fileprivate struct DeviationProbe {
    /// The lattice itself, separated from the polygons so that a section with holes or islands builds
    /// it once rather than once per group. Its samples depend only on the shaping function and the
    /// path, neither of which varies between the groups of one section pair.
    struct Lattice {
        struct Sample {
            let fraction: Double
            /// The blend parameter the shaping function asks for at this fraction.
            let shaping: Double
            /// Where the path's own frame sits here, read out of the frame array.
            let point: Vector3D
            /// That frame's roll about the path, in radians, or zero where the frames state none.
            let angle: Double
        }

        let samples: [Sample]
        /// One lattice step, in fraction units.
        let step: Double

        /// Walks the lattice and the frame array together in a single pass.
        ///
        /// Both are sorted and the lattice is uniform, so the frame bracketing each sample is found by
        /// advancing one index rather than by searching from scratch every time. This is the whole
        /// cost of the probe, and it needs to stay well under the cost of one ring.
        ///
        /// Reading the frames is deliberate, rather than calling `exactFrame`, which would evaluate
        /// the curve and construct a frame at every lattice point. The frames are the path's own
        /// sampling, so every feature the path has is already resolved among them, and the roll they
        /// carry has been unwrapped and twist damped, which a freshly built frame would not know
        /// about. Between two frames this treats the path as straight, which is exactly the
        /// approximation the frame spacing was chosen to make safe.
        init(
            shaping: (Double) -> Double,
            frames: [ParametricCurveFrame],
            startDistance: Double,
            span: Double,
            count: Int
        ) {
            let count = max(count, 4)
            self.step = 1 / Double(count)

            var samples: [Sample] = []
            samples.reserveCapacity(count + 1)
            var frameIndex = 0
            for index in 0...count {
                let fraction = Double(index) / Double(count)
                let distance = startDistance + span * fraction

                while frameIndex + 2 < frames.count, frames[frameIndex + 1].distance <= distance {
                    frameIndex += 1
                }

                var point = Vector3D.zero
                var angle = 0.0
                if frameIndex + 1 < frames.count {
                    let lower = frames[frameIndex]
                    let upper = frames[frameIndex + 1]
                    let gap = upper.distance - lower.distance
                    let within = gap > 1e-12 ? min(max((distance - lower.distance) / gap, 0), 1) : 0
                    let lowerAngle = lower.angle?.radians ?? 0
                    let upperAngle = upper.angle?.radians ?? lowerAngle
                    point = lower.point + (upper.point - lower.point) * within
                    angle = lowerAngle + (upperAngle - lowerAngle) * within
                } else if let only = frames.first {
                    point = only.point
                    angle = only.angle?.radians ?? 0
                }

                samples.append(Sample(fraction: fraction, shaping: shaping(fraction), point: point, angle: angle))
            }
            self.samples = samples
        }
    }

    private let lattice: Lattice
    /// The furthest any single vertex travels as the blend runs from the lower section to the upper
    /// one. Multiplying a blend error by this turns it into a distance.
    private let morphScale: Double
    /// The furthest any vertex sits from its own frame's origin. Multiplying a roll error in radians
    /// by this turns it into a distance.
    private let maximumRadius: Double

    init(lattice: Lattice, lower: SimplePolygon, upper: SimplePolygon) {
        self.lattice = lattice
        // Vertices are blended one for one, so a blend error of d moves vertex i by d times its own
        // travel, and the largest travel bounds them all.
        self.morphScale = zip(lower.vertices, upper.vertices).reduce(0) { max($0, ($1.1 - $1.0).magnitude) }
        self.maximumRadius = max(
            lower.vertices.reduce(0) { max($0, $1.magnitude) },
            upper.vertices.reduce(0) { max($0, $1.magnitude) }
        )
    }

    /// The lattice point inside `range` whose ring is estimated to sit furthest from a straight band
    /// across the range, or `nil` when there is nothing there worth building a ring for.
    ///
    /// `tested` lists the fractions the caller is going to build rings at anyway. A candidate within
    /// one lattice step of one of those is skipped, since the ring the caller already builds is close
    /// enough to measure the same error. That is what keeps this free on an ordinary bulging function
    /// like `.circularEaseOut`, whose worst point is near the middle: its ring counts are unchanged.
    /// A ring is spent only where the surface leaves the band somewhere the fixed fractions cannot
    /// see.
    func worstFraction(in range: Range<Double>, tested: [Double]) -> Double? {
        let samples = lattice.samples
        let step = lattice.step
        // The lattice is uniform, so the bracketing indices come straight from the fractions.
        let firstIndex = max(Int(ceil(range.lowerBound / step - 1e-9)), 0)
        let lastIndex = min(Int(floor(range.upperBound / step + 1e-9)), samples.count - 1)
        guard lastIndex - firstIndex >= 2 else { return nil }

        let low = samples[firstIndex]
        let high = samples[lastIndex]
        let width = high.fraction - low.fraction
        guard width > 1e-12 else { return nil }

        var bestFraction: Double?
        var bestEstimate = 0.0
        for index in (firstIndex + 1)..<lastIndex {
            let sample = samples[index]
            if tested.contains(where: { abs(sample.fraction - $0) <= step }) { continue }

            let fraction = (sample.fraction - low.fraction) / width
            // A distance estimate, summed rather than combined properly. Each term is the largest
            // displacement its own error can cause, so the sum overstates the true one, which is the
            // right way round for a search: it can send the test somewhere it did not need to go, but
            // it cannot talk it out of somewhere it did.
            let blendError = abs(sample.shaping - (low.shaping + (high.shaping - low.shaping) * fraction))
            let pointError = (sample.point - (low.point + (high.point - low.point) * fraction)).magnitude
            let angleError = abs(sample.angle - (low.angle + (high.angle - low.angle) * fraction))
            let estimate = blendError * morphScale + pointError + angleError * maximumRadius

            if estimate > bestEstimate {
                bestEstimate = estimate
                bestFraction = sample.fraction
            }
        }
        return bestEstimate > 0 ? bestFraction : nil
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
