import Foundation

/// Builds the tool solid for one found edge: the edge shape's cross-section swept along the
/// chain with mitered joints. For convex edges the tool is subtracted from the body; for
/// concave edges it's added.
///
/// The tool is one watertight mesh per chain, keeping the number of boolean operations low
/// regardless of how many segments the edge has.
///
internal enum EdgeToolSweep {
    /// How far the cross-section extends past the body's faces, ensuring boolean operations
    /// cross the surfaces cleanly instead of leaving coplanar slivers.
    static let faceOvershoot = 1e-3

    /// How far behind the edge apex the cross-section closes, as a fraction of the shape's setback.
    static let apexOvershootFraction = 0.25

    /// The most a miter projection is allowed to stretch a cross-section, limiting extreme joints.
    private static let maxMiterStretch = 4.0

    /// The most a chain's tangent setback is allowed to exceed its own span, limiting how far a
    /// tool can reach past a degenerate edge. A fillet's setback (radius / tan(wedgeAngle/2))
    /// diverges as the wedge narrows; a wedge this acute is almost always a near-tangency seam
    /// between two boolean-combined curves rather than a real corner, so such a chain is left
    /// unshaped instead of sweeping a needle-like tool far beyond it.
    private static let maxSetbackToSpanFactor = 4.0

    /// The fraction of the tangent setback by which a joint's two projected sections must
    /// disagree before the joint counts as a section transition to blend over a distance.
    /// Ordinary direction miters project to coinciding sections and stay untouched.
    private static let blendMismatchThreshold = 0.05

    /// How far a section transition is spread along the chain to each side, as a multiple of
    /// the larger tangent setback of the two meeting sections.
    private static let blendWindowFactor = 2.0

    /// How many rings a transition's blend window is guaranteed to span on each side,
    /// by subdividing segments that don't already have joints there.
    private static let blendSubdivisions = 5

    /// Below this length, a segment is treated as noise rather than a real piece of the edge,
    /// regardless of the chain it belongs to.
    private static let degenerateSegmentLength = 1e-9

    /// A segment shorter than this fraction of its own chain's longest segment is also treated
    /// as noise, on top of the absolute floor above.
    ///
    /// A single absolute cutoff can't serve every chain: some edges are made up entirely of
    /// segments a few hundredths of a millimeter long (still real, still meant to be swept), while
    /// others carry one degenerate sliver alongside segments many millimeters long. Sizing the
    /// cutoff relative to the chain's own longest segment catches an extreme outlier within a
    /// chain without disturbing a chain whose segments are all uniformly short.
    private static let relativeDegenerateSegmentFactor = 1e-6

    /// A generated tool solid, along with its terminal cross-section rings which corner
    /// patches use as hull points.
    struct SweptTool {
        let geometry: any Geometry3D
        let startSectionPoints: [Vector3D]
        let endSectionPoints: [Vector3D]
    }

    /// The cross-section frame of one segment: right-handed with Z along the segment,
    /// X pointing into the wedge being modified. Cross-sections are constant along a segment.
    private struct SegmentBasis {
        let xAxis: Vector3D
        let yAxis: Vector3D
        let wedgeAngle: Angle
    }

    /// Returns the swept tool solid for the given edge, or nil if the edge is degenerate.
    ///
    /// For open edges, `startRetraction`/`endRetraction` pull the terminal cross-sections
    /// inward along the chain, making room for corner patches at junctions.
    static func tool(
        for edge: FoundEdge,
        shape: EdgeShape,
        segmentation: Segmentation,
        startRetraction: Double = 0,
        endRetraction: Double = 0
    ) -> SweptTool? {
        let relativeFloor = (edge.segments.map(\.length).max() ?? 0) * Self.relativeDegenerateSegmentFactor
        let lengthFloor = max(Self.degenerateSegmentLength, relativeFloor)
        var segments = edge.segments.filter { $0.length > lengthFloor }
        let isClosed = edge.isClosed
        if !isClosed {
            segments = retracted(segments, start: startRetraction, end: endRetraction)
        }
        guard !segments.isEmpty else { return nil }

        let bases = segments.compactMap(basis(for:))
        guard bases.count == segments.count else { return nil }

        let segmentCount = bases.map {
            shape.preferredSegmentCount(wedgeAngle: $0.wedgeAngle, segmentation: segmentation)
        }.max() ?? 1

        let maxSetback = bases.map { shape.tangentSetback(wedgeAngle: $0.wedgeAngle) }.max() ?? 0
        guard maxSetback > 0 else { return nil }

        let chainSpan = segments.reduce(0) { $0 + $1.length }
        guard maxSetback < chainSpan * maxSetbackToSpanFactor else { return nil }

        let sections = bases.map { basis in
            crossSection(
                shape: shape, wedgeAngle: basis.wedgeAngle, isConvex: edge.isConvex,
                segmentCount: segmentCount, apexDepth: maxSetback * apexOvershootFraction
            )
        }
        guard let pointCount = sections.first?.count, pointCount >= 3,
              sections.allSatisfy({ $0.count == pointCount })
        else { return nil }

        // Each ring is the adjacent segments' cross-sections projected along the segment
        // direction onto the joint's miter plane; at an ordinary mitered joint, the two
        // projections coincide, stretching the section exactly as a miter joint requires.
        // Where they differ — the adjoining faces twisting or the wedge angle changing at
        // the joint, as when the edge crosses a shallow crease in a face it runs along —
        // the ring combines them pointwise: the outer choice along the curve's interior, so
        // the tool covers what both orientations demand (like the rolling ball pivoting at
        // the crossing), while the face-hugging points follow the inner candidate's ray
        // (staying buried under both adjoining faces) widened to the outer candidate's
        // reach, so the swollen curve descends onto the faces instead of overhanging them.
        // An averaged section would match neither face, leaving flanks partially exposed
        // and corners unfilled.
        let curveInteriorIndices = 4..<max(4, pointCount - 2)

        func combined(_ a: Vector3D, _ b: Vector3D, vertex: Vector3D, pointIndex: Int) -> Vector3D {
            let toA = a - vertex
            let toB = b - vertex
            let aIsOuter = toA.squaredEuclideanNorm >= toB.squaredEuclideanNorm
            if curveInteriorIndices.contains(pointIndex) {
                return aIsOuter ? a : b
            } else {
                let inner = aIsOuter ? toB : toA
                let innerLength = inner.magnitude
                guard innerLength > 1e-12 else { return aIsOuter ? a : b }
                let outerLength = aIsOuter ? toA.magnitude : toB.magnitude
                return vertex + inner * (outerLength / innerLength)
            }
        }

        struct Joint {
            let vertex: Vector3D
            let miterNormal: Vector3D
            let projections: [[Vector3D]]
            var ring: [Vector3D]
        }

        struct Transition {
            let ringIndex: Int
            let arcPosition: Double
            let window: Double
            let arrivingSegment: Int
            let leavingSegment: Int
        }

        struct Layout {
            let segments: [EdgeSegment]
            let bases: [SegmentBasis]
            let sections: [[Vector2D]]
            let arcPositions: [Double]
            let chainLength: Double
            var joints: [Joint]
            let transitions: [Transition]
        }

        func layout(for segments: [EdgeSegment]) -> Layout? {
            let bases = segments.compactMap(basis(for:))
            guard bases.count == segments.count else { return nil }
            let sections = bases.map { basis in
                crossSection(
                    shape: shape, wedgeAngle: basis.wedgeAngle, isConvex: edge.isConvex,
                    segmentCount: segmentCount, apexDepth: maxSetback * apexOvershootFraction
                )
            }
            guard sections.allSatisfy({ $0.count == pointCount }) else { return nil }

            let ringCount = isClosed ? segments.count : segments.count + 1
            var arcPositions: [Double] = [0]
            for segment in segments { arcPositions.append(arcPositions.last! + segment.length) }
            let setbacks = bases.map { shape.tangentSetback(wedgeAngle: $0.wedgeAngle) }

            let joints: [Joint] = (0..<ringCount).map { index in
                let arriving = isClosed ? (index + segments.count - 1) % segments.count : index - 1
                let leaving = isClosed ? index : (index < segments.count ? index : -1)
                let vertex = index < segments.count ? segments[index].start : segments[segments.count - 1].end

                let adjacent = [arriving, leaving].filter { $0 >= 0 && $0 < segments.count }
                let directionSum = adjacent.reduce(Vector3D.zero) { $0 + segments[$1].direction.unitVector }
                let miterNormal = directionSum.magnitude > 1e-9
                    ? directionSum.normalized
                    : segments[adjacent[0]].direction.unitVector

                let projections = adjacent.map { segmentIndex in
                    projectedSection(
                        section: sections[segmentIndex],
                        basis: bases[segmentIndex],
                        direction: segments[segmentIndex].direction.unitVector,
                        vertex: vertex,
                        miterNormal: miterNormal
                    )
                }

                let ring: [Vector3D]
                if let first = projections.first, projections.count == 2 {
                    ring = zip(first, projections[1]).enumerated().map { pointIndex, points in
                        combined(points.0, points.1, vertex: vertex, pointIndex: pointIndex)
                    }
                } else {
                    ring = projections.first ?? []
                }
                return Joint(vertex: vertex, miterNormal: miterNormal, projections: projections, ring: ring)
            }
            guard joints.allSatisfy({ $0.ring.count == pointCount }) else { return nil }

            let transitions: [Transition] = (0..<ringCount).compactMap { index in
                let joint = joints[index]
                guard joint.projections.count == 2 else { return nil }
                let mismatch = zip(joint.projections[0], joint.projections[1])
                    .map { ($0 - $1).magnitude }.max() ?? 0
                guard mismatch > maxSetback * blendMismatchThreshold else { return nil }
                let arriving = isClosed ? (index + segments.count - 1) % segments.count : index - 1
                return Transition(
                    ringIndex: index,
                    arcPosition: arcPositions[index],
                    window: blendWindowFactor * max(setbacks[arriving], setbacks[index % segments.count]),
                    arrivingSegment: arriving,
                    leavingSegment: index % segments.count
                )
            }

            return Layout(
                segments: segments, bases: bases, sections: sections,
                arcPositions: arcPositions, chainLength: arcPositions[segments.count],
                joints: joints, transitions: transitions
            )
        }

        guard var built = layout(for: segments) else { return nil }

        // An envelope ring alone still switches sections at a single joint, which reads as a
        // sudden step in the swept shape. Spread each such transition over a distance: rings
        // near it blend toward the combination of their own section and the far side's,
        // fading with arc distance, so the tool swells smoothly through the crossing.
        //
        // Rings only exist at joints, and a transition at the end of a long straight segment
        // has no nearby joints — its swollen ring would stretch across the whole segment. So
        // first subdivide the chain within each transition's window to give the swell rings
        // to decay across, and rebuild.
        if !built.transitions.isEmpty {
            var cuts: [Double] = []
            for transition in built.transitions {
                for step in 1...blendSubdivisions {
                    let offset = transition.window * Double(step) / Double(blendSubdivisions)
                    cuts.append(transition.arcPosition - offset)
                    cuts.append(transition.arcPosition + offset)
                }
            }
            let refined = subdivided(built.segments, atArcPositions: cuts, isClosed: isClosed, chainLength: built.chainLength)
            if refined.count != built.segments.count, let refinedLayout = layout(for: refined) {
                built = refinedLayout
            }
        }

        segments = built.segments
        let ringCount = isClosed ? segments.count : segments.count + 1

        for index in 0..<ringCount {
            for transition in built.transitions where transition.ringIndex != index {
                // The foreign section is the one on the far side of the transition, as seen
                // from this ring; distance is measured along the chain
                let distance: Double
                let farSegment: Int
                if isClosed {
                    let forward = (built.arcPositions[index] - transition.arcPosition + built.chainLength)
                        .truncatingRemainder(dividingBy: built.chainLength)
                    if forward <= built.chainLength - forward {
                        distance = forward
                        farSegment = transition.arrivingSegment
                    } else {
                        distance = built.chainLength - forward
                        farSegment = transition.leavingSegment
                    }
                } else {
                    let offset = built.arcPositions[index] - transition.arcPosition
                    distance = abs(offset)
                    farSegment = offset > 0 ? transition.arrivingSegment : transition.leavingSegment
                }
                guard distance < transition.window else { continue }

                let fraction = 1 - distance / transition.window
                let weight = fraction * fraction * (3 - 2 * fraction)  // smoothstep
                let joint = built.joints[index]
                let foreign = projectedSection(
                    section: built.sections[farSegment],
                    basis: built.bases[farSegment],
                    direction: segments[farSegment].direction.unitVector,
                    vertex: joint.vertex,
                    miterNormal: joint.miterNormal
                )
                built.joints[index].ring = joint.ring.enumerated().map { pointIndex, point in
                    let target = combined(point, foreign[pointIndex], vertex: joint.vertex, pointIndex: pointIndex)
                    return point + (target - point) * weight
                }
            }
        }

        let rings = built.joints.map(\.ring)

        var faces: [[Vector3D]] = []
        for ring in 0..<(isClosed ? ringCount : ringCount - 1) {
            let next = (ring + 1) % ringCount
            for pointIndex in 0..<pointCount {
                let nextPoint = (pointIndex + 1) % pointCount
                let a = rings[ring][pointIndex]
                let b = rings[ring][nextPoint]
                let c = rings[next][nextPoint]
                let d = rings[next][pointIndex]
                // Sections can differ between rings, making quads non-planar; emit triangles
                faces.append([a, b, c])
                faces.append([a, c, d])
            }
        }

        if !isClosed {
            faces.append(rings[0].reversed())   // start cap, facing backwards
            faces.append(rings[ringCount - 1])  // end cap, facing forwards
        }

        let mesh = Mesh(
            faces: faces,
            name: "Cadova.EdgeToolSweep",
            cacheParameters: edge, shape, segmentation, startRetraction, endRetraction
        )
        return SweptTool(
            geometry: mesh.correctingFaceWinding(),
            startSectionPoints: rings[0],
            endSectionPoints: rings[ringCount - 1]
        )
    }

    // MARK: - Retraction

    /// Shortens an open chain from its ends, dropping fully consumed segments and trimming
    /// the remainder — retractions routinely exceed individual segment lengths on finely
    /// segmented curved chains. Chains too short to retract keep their flush ends.
    private static func retracted(_ segments: [EdgeSegment], start: Double, end: Double) -> [EdgeSegment] {
        guard start > 0 || end > 0 else { return segments }
        let totalLength = segments.reduce(0) { $0 + $1.length }
        guard start + end < totalLength * 0.9 else { return segments }

        var result = segments[...]

        var remaining = start
        while let first = result.first, remaining >= first.length - 1e-9 {
            remaining -= first.length
            result.removeFirst()
        }
        if remaining > 0, let first = result.first {
            result[result.startIndex] = EdgeSegment(
                start: first.start + first.direction.unitVector * remaining,
                end: first.end,
                leftFaceNormal: first.leftFaceNormal,
                rightFaceNormal: first.rightFaceNormal
            )
        }

        remaining = end
        while let last = result.last, remaining >= last.length - 1e-9 {
            remaining -= last.length
            result.removeLast()
        }
        if remaining > 0, let last = result.last {
            result[result.endIndex - 1] = EdgeSegment(
                start: last.start,
                end: last.end - last.direction.unitVector * remaining,
                leftFaceNormal: last.leftFaceNormal,
                rightFaceNormal: last.rightFaceNormal
            )
        }

        return Array(result)
    }

    /// Splits segments at the given arc-length positions along the chain, so that rings can
    /// exist there. Positions outside an open chain are ignored; positions on a closed chain
    /// wrap around. Cuts landing within a small tolerance of an existing joint are skipped.
    private static func subdivided(
        _ segments: [EdgeSegment],
        atArcPositions positions: [Double],
        isClosed: Bool,
        chainLength: Double
    ) -> [EdgeSegment] {
        let cuts: [Double] = positions.compactMap { position in
            if isClosed {
                let wrapped = position.truncatingRemainder(dividingBy: chainLength)
                return wrapped < 0 ? wrapped + chainLength : wrapped
            } else {
                return (position > 0 && position < chainLength) ? position : nil
            }
        }.sorted()

        var result: [EdgeSegment] = []
        var segmentStart = 0.0
        var cutIndex = 0
        for segment in segments {
            let segmentEnd = segmentStart + segment.length
            var pieceStart = segment.start
            var pieceArc = segmentStart
            while cutIndex < cuts.count, cuts[cutIndex] < segmentEnd - 1e-6 {
                let cut = cuts[cutIndex]
                cutIndex += 1
                guard cut > pieceArc + 1e-6 else { continue }
                let point = segment.start + segment.direction.unitVector * (cut - segmentStart)
                result.append(EdgeSegment(
                    start: pieceStart, end: point,
                    leftFaceNormal: segment.leftFaceNormal, rightFaceNormal: segment.rightFaceNormal
                ))
                pieceStart = point
                pieceArc = cut
            }
            result.append(EdgeSegment(
                start: pieceStart, end: segment.end,
                leftFaceNormal: segment.leftFaceNormal, rightFaceNormal: segment.rightFaceNormal
            ))
            segmentStart = segmentEnd
        }
        return result
    }

    // MARK: - Segment frames

    /// The in-plane directions pointing away from the edge along each of the segment's faces.
    static func faceRays(of segment: EdgeSegment) -> (left: Vector3D, right: Vector3D) {
        let direction = segment.direction.unitVector
        return (
            left: segment.leftFaceNormal.unitVector × direction,
            right: direction × segment.rightFaceNormal.unitVector
        )
    }

    private static func basis(for segment: EdgeSegment) -> SegmentBasis? {
        let rays = faceRays(of: segment)
        let bisector = rays.left + rays.right
        guard bisector.magnitude > 1e-9 else { return nil }

        let xAxis = bisector.normalized
        let yAxis = segment.direction.unitVector × xAxis
        return SegmentBasis(xAxis: xAxis, yAxis: yAxis, wedgeAngle: segment.wedgeAngle)
    }

    /// Places a segment's 2D cross-section at a joint vertex and projects it along the segment
    /// direction onto the joint's miter plane.
    private static func projectedSection(
        section: [Vector2D],
        basis: SegmentBasis,
        direction: Vector3D,
        vertex: Vector3D,
        miterNormal: Vector3D
    ) -> [Vector3D] {
        let alignment = direction ⋅ miterNormal
        // Limit the stretch at extreme turns to keep the mesh sane
        let slope = abs(alignment) > 1 / maxMiterStretch ? 1 / alignment : 0

        return section.map { local in
            let point = vertex + basis.xAxis * local.x + basis.yAxis * local.y
            return point - direction * (((point - vertex) ⋅ miterNormal) * slope)
        }
    }

    // MARK: - Cross-section

    /// Builds the closed 2D cross-section polygon for a segment, in counterclockwise order.
    ///
    /// The polygon consists of the shape's curve (running from face to face), endpoints
    /// extended slightly past the faces, and a closing edge behind the edge apex.
    ///
    /// Layout (relied upon by the ring envelope in `tool(for:...)`): indices 0–1 are the
    /// behind-apex corners, 2 is the extended endpoint of the negative-angle face, then the
    /// curve from its negative-angle end to its positive-angle end, and finally the extended
    /// endpoint of the positive-angle face. The curve's interior therefore spans indices
    /// 4 through `count - 3`.
    static func crossSection(
        shape: EdgeShape,
        wedgeAngle: Angle,
        isConvex: Bool,
        segmentCount: Int,
        apexDepth: Double
    ) -> [Vector2D] {
        let curve = shape.curvePoints(wedgeAngle: wedgeAngle, isConvex: isConvex, segmentCount: segmentCount)
        guard let first = curve.first, let last = curve.last else { return [] }

        let halfAngle = wedgeAngle / 2
        // Perpendicular to each face, pointing out of the wedge
        let firstExtended = first + Vector2D(-sin(halfAngle), cos(halfAngle)) * faceOvershoot
        let lastExtended = last + Vector2D(-sin(halfAngle), -cos(halfAngle)) * faceOvershoot

        let section = [firstExtended] + curve + [
            lastExtended,
            Vector2D(-apexDepth, lastExtended.y),
            Vector2D(-apexDepth, firstExtended.y),
        ]

        // The construction above runs clockwise; reverse for counterclockwise winding
        return section.reversed()
    }
}
