import Foundation
import Manifold3D

/// A profile used to modify the edge of a 3D shape, such as for chamfers or fillets, with
/// independent horizontal and vertical dimensions anchored to a fixed frame.
///
/// The profile is defined in 2D, where:
/// - The X axis is horizontal; negative X points inward, positive X outward from the edge
/// - The Y axis is vertical; positive Y points outward from the edge face
///
/// This fixed frame makes `EdgeProfile` suited to locations with a known orientation,
/// such as extrusion caps, box edges, and print-orientation-aware profiles like
/// `overhangFillet(radius:)`. For edges of unknown or varying orientation — such as those found
/// on an arbitrary model with `readingEdges(matching:)` — use the mirror-symmetric ``EdgeShape``
/// instead, which adapts to any dihedral angle and handles cut-vs-fill automatically.
///
public struct EdgeProfile: Sendable {
    public let profile: any Geometry2D

    /// Creates a new edge profile.
    /// - Parameter profile: A 2D geometry builder describing the profile cross-section. The profile is automatically
    ///   aligned so that its bottom-right corner is at the origin.
    ///
    public init(@GeometryBuilder2D profile: @Sendable @escaping () -> any Geometry2D) {
        self.profile = profile().aligned(at: .max)
    }

    public var negativeShape: any Geometry2D {
        readingNegativeShape { negativeShape, _ in
            negativeShape
        }
    }
}

internal extension EdgeProfile {
    func readingNegativeShape<D: Dimensionality>(
        @GeometryBuilder<D> reader: @Sendable @escaping (_ negativeProfile: any Geometry2D, _ size: Vector2D) -> D.Geometry
    ) -> D.Geometry {
        profile.measuringBounds { shape, bounds in
            let negativeShape = Rectangle(bounds.size)
                .aligned(at: .max)
                .subtracting { shape }

            reader(negativeShape, bounds.size)
        } empty: {
            reader(Empty(), .zero)
        }
    }

    /// The most a miter joint is allowed to stretch away from the vertex it's anchored to, as a
    /// factor of the profile's own size — mirrors `EdgeToolSweep.maxMiterStretch`, which guards
    /// the same instability in the newer edge-shaping system.
    private static let maxMiterStretch = 8.0

    /// The direction and stretch of the miter joint at a polygon vertex, given the incoming and
    /// outgoing edge vectors (in that order).
    ///
    /// The direction is the normal of the two edges' bisector — the standard miter join — and the
    /// stretch is how much a cross-section placed along that direction must widen so its
    /// silhouette stays constant across the joint. `alignment` (how closely the bisector's normal
    /// tracks the outgoing edge) shrinks toward zero at both ends of the turn-angle range: a turn
    /// approaching a flat cusp (as where two boolean-combined curves meet almost tangentially,
    /// incoming and outgoing nearly antiparallel) *and* an extremely sharp spike vertex (incoming
    /// and outgoing also nearly antiparallel, just because the interior angle is tiny) are both
    /// captured by the same small-`alignment` guard, even though geometrically they're opposite
    /// shapes. The bisector direction itself stays well-defined and meaningful in both cases —
    /// only the stretch genuinely diverges — so the guard caps the stretch at `maxMiterStretch`
    /// and keeps the bisector-derived direction; it must not substitute a different direction
    /// (e.g. the outgoing edge's own normal), because that direction is only a reasonable stand-in
    /// for the *shared* vertex when incoming and outgoing already roughly agree, which isn't
    /// guaranteed here. (Substituting outgoing's normal here previously caused a large,
    /// direction-only discontinuity at very sharp spikes — e.g. a thin wedge tip — where the ring
    /// shared with the *incoming* segment ended up twisted around 140° from that segment's own
    /// bisector, leaving its swept tool barely overlapping the body at all.) Only the true
    /// degenerate case — the bisector itself undefined because the normalized sum collapses to
    /// zero at an exact cusp — still needs a substitute direction, since there's no bisector left
    /// to cap. This must stay a pure function of the two edge vectors: the same vertex terminates
    /// one segment's ring and starts the next one's, and both need the identical joint to weld
    /// exactly.
    private func miterOffset(_ incoming: Vector2D, _ outgoing: Vector2D) -> (direction: Direction2D, stretch: Double, isCapped: Bool) {
        let sum = incoming.normalized + outgoing.normalized
        let sumMagnitude = sum.magnitude
        guard sumMagnitude > 1e-9 else {
            return (Direction2D(outgoing).counterclockwiseNormal, 1, true)
        }
        let bisector = sum / sumMagnitude
        let alignment = bisector ⋅ outgoing.normalized
        guard alignment > 1 / Self.maxMiterStretch else {
            return (Direction2D(bisector).counterclockwiseNormal, Self.maxMiterStretch, true)
        }
        return (Direction2D(bisector).counterclockwiseNormal, 1 / alignment, false)
    }

    /// Below this edge length, a polygon vertex is treated as noise rather than a real corner.
    ///
    /// Boolean and rounding operations routinely leave near-duplicate vertices behind — points a
    /// few nanometers apart, well under any printable feature size (`shape.simplified()` above
    /// only cleans these up when the caller's environment happens to set
    /// `simplificationThreshold`, which most models never do — and it does more than dedupe
    /// exact overlaps, so raising its threshold to cover this also perturbs unrelated, meaningful
    /// vertices elsewhere on the curve). Left in place, such a segment's direction (`c - b`) is
    /// dominated by floating-point noise, so the tool piece built for it gets an essentially
    /// arbitrary rotation — producing a malformed, often folded-back sliver in the cutting tool.
    private static let degenerateEdgeLength = 1e-6

    /// Drops vertices that leave a near-zero-length edge to the next surviving point, wrapping
    /// around the closed polygon. A run of several such points collapses to the last one.
    ///
    /// `threshold` defaults to `degenerateEdgeLength`, sized for the outer curve's own noise
    /// floor. A cross-section fed through this (see `followingEdge`'s `regionPolygons` cleanup)
    /// needs a far smaller threshold instead — its edges can legitimately be as short as
    /// `interfaceMargin`, the same order of magnitude as `degenerateEdgeLength`, so the default
    /// would eat real geometry there, not just construction artifacts.
    private func droppingDegenerateVertices(_ vertices: [Vector2D], threshold: Double = Self.degenerateEdgeLength) -> [Vector2D] {
        guard vertices.count > 3 else { return vertices }
        var result: [Vector2D] = [vertices[0]]
        for vertex in vertices.dropFirst() {
            if (vertex - result[result.count - 1]).magnitude > threshold {
                result.append(vertex)
            }
        }
        if result.count > 1, (result[0] - result[result.count - 1]).magnitude <= threshold {
            result.removeLast()
        }
        return result
    }

    /// How far the swept region extends past its interface faces — the sides where the tool
    /// would otherwise coincide exactly with a face of the body it's cut from or added to.
    /// A cutting tool reaches this far beyond the wall and above the edge face, and a forming
    /// tool this far into the wall, so booleans cross those surfaces cleanly instead of
    /// resolving exactly-coincident faces (which can leave zero-volume membranes and
    /// micro-slivers behind). The profile's cut/fill surface itself stays exact; only the
    /// interface sides are extended.
    private static let interfaceMargin = 1e-2

    /// Builds the actual ring matrix from an already-resolved direction, stretch, and vertex:
    /// maps a swept-region point (x, y) to (vertex + miterDirection * -x * stretch, y).
    private func ringTransform(direction: Direction2D, stretch: Double, vertex: Vector2D) -> Transform3D {
        let xAxis = -direction.unitVector * stretch
        return Transform3D([
            [xAxis.x, 0, -direction.unitVector.y, vertex.x],
            [xAxis.y, 0, direction.unitVector.x, vertex.y],
            [0, 1, 0, 0],
            [0, 0, 0, 1],
        ])
    }

    /// The cross-section ring at one polygon vertex. The ring is computed once per vertex and
    /// shared by the segments on both sides, so their meeting faces have bit-identical vertices
    /// and the union welds them exactly — the seams can't leave coplanar-resolution debris the
    /// way independently trimmed prisms did.
    private func ringTransform(at vertex: Vector2D, incoming: Vector2D, outgoing: Vector2D) -> Transform3D {
        let (direction, stretch, _) = miterOffset(incoming, outgoing)
        return ringTransform(direction: direction, stretch: stretch, vertex: vertex)
    }

    /// A chain of ring transforms smoothly interpolated between two already-resolved joints,
    /// used for a segment where either endpoint's stretch was capped by `miterOffset` — direction
    /// and stretch can differ enormously between such a joint and its neighbor (e.g. a normal
    /// corner's small stretch next to a capped spike's `maxMiterStretch`), and connecting the two
    /// directly in one step sweeps the profile through that whole change in a single flat facet,
    /// producing a visibly creased, non-planar bevel instead of a smooth one. Interpolating by
    /// angle (not by lerping the raw transform matrices, which doesn't sweep through a proper
    /// rotation for a large angle difference) spreads the same total change over many small
    /// facets, closely approximating a smooth bevel.
    private func interpolatedRingTransforms(
        from a: (vertex: Vector2D, direction: Direction2D, stretch: Double),
        to b: (vertex: Vector2D, direction: Direction2D, stretch: Double),
        steps: Int
    ) -> [Transform3D] {
        let angleA = Foundation.atan2(a.direction.unitVector.y, a.direction.unitVector.x)
        let angleB = Foundation.atan2(b.direction.unitVector.y, b.direction.unitVector.x)
        var deltaAngle = angleB - angleA
        if deltaAngle > .pi { deltaAngle -= 2 * .pi }
        if deltaAngle < -.pi { deltaAngle += 2 * .pi }

        return (0...steps).map { step in
            let t = Double(step) / Double(steps)
            let vertex = a.vertex + (b.vertex - a.vertex) * t
            let angle = angleA + deltaAngle * t
            let direction = Direction2D(Vector2D(x: Foundation.cos(angle), y: Foundation.sin(angle)))
            let stretch = a.stretch + (b.stretch - a.stretch) * t
            return ringTransform(direction: direction, stretch: stretch, vertex: vertex)
        }
    }

    func followingEdge(of shape: any Geometry2D, type: EnvironmentValues.Operation) -> any Geometry3D {
        profile.measuringBounds { profileShape, bounds in
            let margin = Self.interfaceMargin
            // A cutting tool reaches past the edge face into open space; a forming tool stops
            // just short of it. Either way, no tool face lands exactly in the face's plane,
            // where the boolean would resolve it unreliably.
            let topMargin = type == .subtraction ? margin : -margin
            let sweptRegion = Rectangle(x: bounds.size.x + margin, y: bounds.size.y + topMargin)
                .aligned(at: .max)
                .translated(x: margin, y: topMargin)
                .subtracting { profileShape }
                // The addition/forming case's own per-segment tool pieces, when unioned with
                // each other (before ever touching the body), can leave a thin near-duplicate
                // ring at the outer/flared edge of the profile — confirmed present in the tool
                // alone, so it's a self-union issue between neighboring segments, not a
                // tool/body interface issue (`interfaceMargin` above has no effect on it, at
                // any value from 1e-6 to 1e-1). Growing the whole cross-section by a small,
                // fixed amount gives adjacent segments' pieces enough overlap to merge cleanly.
                // `.miter` style specifically — `.round` was tried first and made this worse, by
                // introducing fresh tessellated points at the profile's own corners that
                // reintroduced the same class of instability it was meant to fix. Subtraction
                // mode doesn't show this defect (its tool is clean in isolation — the earlier
                // subtraction-mode bug was a tool/body interface issue, fixed via
                // `interfaceMargin` instead), so this is scoped to `.addition` only.
                .offset(amount: type == .addition ? 0.01 : 0, style: .miter)
                .adding {
                    // Dip the wall-side margin strip below the profile's lower tip. Without
                    // this, the strip's bottom corner rests exactly on the wall line, and
                    // grazing contact resolves as unreliably as coincident faces do.
                    //
                    // Added after the offset above, not before: attaching this thin appendage
                    // to the boundary *before* offsetting used to confuse the miter-offset's
                    // corner resolution right at the attachment point — regardless of the tab's
                    // own width or depth, offsetting it always left a near-duplicate vertex pair
                    // a hair apart instead of one clean point (confirmed by direct inspection of
                    // the offset's output polygon: the same fault position and magnitude
                    // persisted across multiple tab sizes). Attaching it afterward sidesteps the
                    // interaction entirely — the tab never has to survive an offset.
                    Rectangle(x: margin, y: margin * 2)
                        .translated(x: 0, y: -bounds.size.y - margin)
                }

            let tool = sweptRegion.readingConcrete { regionSection in
                // The rectangle-plus-margin-strip construction above can leave a redundant,
                // exactly-coincident vertex where the strip's corner lands on an existing point
                // of the profile's own boundary — e.g. a plain 45° chamfer's swept region comes
                // back from the subtraction with a literal repeated vertex at one corner. Left
                // in place, this duplicate point index confuses `Mesh(extruding:along:)`'s
                // per-vertex correspondence between neighboring rings (confirmed by direct mesh
                // inspection: a triangle ends up spanning from one ring straight to the *next*
                // ring over, skipping the one in between) — producing a real, protruding fold,
                // not just a coincident-face rounding artifact.
                //
                // Can't use `droppingDegenerateVertices`'s default threshold here — it's the same
                // order of magnitude as `interfaceMargin`, which this cross-section legitimately
                // uses to keep otherwise-coincident edges a hair apart. A far smaller threshold
                // only catches true construction-artifact duplicates, not real margin edges.
                let regionPolygons = SimplePolygonList(regionSection.polygonList().polygons.map {
                    SimplePolygon(droppingDegenerateVertices($0.vertices, threshold: 1e-12))
                })
                return shape.simplified().readingConcrete { crossSection in
                    crossSection.polygonList().polygons.mapUnion { polygon in
                        let rawVertices = type == .subtraction ? polygon.vertices : Array(polygon.vertices.reversed())
                        let vertices = droppingDegenerateVertices(rawVertices)
                        let joints = vertices.indices.map { index -> (vertex: Vector2D, direction: Direction2D, stretch: Double, isCapped: Bool) in
                            let (direction, stretch, isCapped) = miterOffset(
                                vertices[wrap: index] - vertices[wrap: index - 1],
                                vertices[wrap: index + 1] - vertices[wrap: index]
                            )
                            return (vertices[wrap: index], direction, stretch, isCapped)
                        }
                        for index in vertices.indices {
                            let a = joints[index]
                            let b = joints[(index + 1) % joints.count]
                            // A capped joint's stretch/direction can differ enormously from its
                            // neighbor's — sweeping the profile through that whole change in one
                            // step leaves a visibly creased, non-planar bevel. Subdividing only
                            // this segment spreads the change smoothly instead.
                            let path = (a.isCapped || b.isCapped)
                                ? interpolatedRingTransforms(from: (a.vertex, a.direction, a.stretch), to: (b.vertex, b.direction, b.stretch), steps: 32)
                                : [
                                    ringTransform(direction: a.direction, stretch: a.stretch, vertex: a.vertex),
                                    ringTransform(direction: b.direction, stretch: b.stretch, vertex: b.vertex),
                                ]
                            Mesh(
                                extruding: regionPolygons,
                                along: path,
                                cacheName: "EdgeProfileSegment",
                                cacheParameters: regionPolygons, path
                            )
                            .correctingFaceWinding()
                        }
                    }
                }
            }

            // Weld the tool into one concrete mesh before it meets the body. Union flattening
            // would otherwise merge the segment prisms into the same n-ary boolean as the body
            // itself, and once any prism merges with the body first, its seam face is
            // retriangulated and no longer matches its neighbor's bit-exactly — leaving the
            // seam to coplanar resolution, which is unreliable. Welding the prisms against
            // each other first keeps every seam an exact shared-vertex interface.
            //
            // On top of that materialization barrier, explicitly re-weld any vertices Manifold's
            // own union left merely near-coincident instead of merged. For most profiles the
            // ring-weld's shared transforms already guarantee bit-identical seam vertices and
            // this is a no-op — but for curved (e.g. fillet) profiles, Manifold's boolean union
            // has been confirmed (by running the identical construction repeatedly) to
            // non-deterministically leave two vertices at the same 3D position unmerged, some
            // runs but not others, producing a degenerate zero-area fold between them. Neither
            // `Manifold.simplify(epsilon:)` nor `MeshGL.merged()` fixes this (the mesh is already
            // a valid closed manifold, just locally folded — there's no open boundary for either
            // to act on). A direct, deterministic Swift-side weld of near-coincident vertices —
            // independent of Manifold's own union resolution — fixes it reliably instead.
            return CachedNodeTransformer<D3, D3>(body: tool, name: "EdgeProfileTool") { node, _, context in
                let manifold = try await context.result(for: node).concrete
                let (vertices, faces) = weldingCoincidentVertices(manifold.meshGL())
                return GeometryNode.shape(.mesh(MeshData(vertices: vertices, faces: faces)))
            }
        }
    }
}

/// Merges vertices of `meshGL` that sit within `tolerance` of each other, dropping any triangle
/// that degenerates (two or more shared corners) as a result. Pure Swift position-matching —
/// deterministic regardless of how Manifold's own boolean union happened to resolve (or not
/// resolve) the same coincidence.
private func weldingCoincidentVertices(_ meshGL: MeshGL, tolerance: Double = 1e-4) -> (vertices: [Vector3D], faces: [[Int]]) {
    let vertices = meshGL.vertices
    let triangles = meshGL.triangles

    var parent = Array(vertices.indices)
    func find(_ x: Int) -> Int {
        var x = x
        while parent[x] != x {
            parent[x] = parent[parent[x]]
            x = parent[x]
        }
        return x
    }
    func union(_ a: Int, _ b: Int) {
        let ra = find(a), rb = find(b)
        if ra != rb { parent[ra] = rb }
    }

    // Spatial hash so near-duplicate lookup stays roughly linear instead of O(n²).
    struct CellKey: Hashable { let x, y, z: Int64 }
    let cellSize = tolerance * 2
    func cell(_ v: Vector3D) -> CellKey {
        CellKey(x: Int64((v.x / cellSize).rounded(.down)), y: Int64((v.y / cellSize).rounded(.down)), z: Int64((v.z / cellSize).rounded(.down)))
    }
    var buckets: [CellKey: [Int]] = [:]
    for (i, v) in vertices.enumerated() {
        buckets[cell(v), default: []].append(i)
    }

    for (i, v) in vertices.enumerated() {
        let base = cell(v)
        for dx in -1...1 { for dy in -1...1 { for dz in -1...1 {
            let key = CellKey(x: base.x + Int64(dx), y: base.y + Int64(dy), z: base.z + Int64(dz))
            guard let candidates = buckets[key] else { continue }
            for j in candidates where j > i {
                if (vertices[j] - v).magnitude < tolerance {
                    union(i, j)
                }
            }
        }}}
    }

    var canonicalIndex: [Int: Int] = [:]
    var newVertices: [Vector3D] = []
    func canonical(_ i: Int) -> Int {
        let root = find(i)
        if let existing = canonicalIndex[root] { return existing }
        let newIndex = newVertices.count
        newVertices.append(vertices[root])
        canonicalIndex[root] = newIndex
        return newIndex
    }

    var newFaces: [[Int]] = []
    newFaces.reserveCapacity(triangles.count)
    for t in triangles {
        let a = canonical(Int(t.a)), b = canonical(Int(t.b)), c = canonical(Int(t.c))
        guard a != b, b != c, a != c else { continue }
        newFaces.append([a, b, c])
    }

    return (newVertices, newFaces)
}
