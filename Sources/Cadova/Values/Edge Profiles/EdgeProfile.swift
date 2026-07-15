import Foundation
import Manifold3D

/// A profile used to modify the edge of a 3D shape, such as for chamfers or fillets.
///
/// The profile is defined in 2D, where:
/// - The X axis is horizontal; negative X points inward, positive X outward from the edge
/// - The Y axis is vertical; positive Y points outward from the edge face
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
    /// Ordinarily the direction is the normal of the two edges' bisector — the standard miter
    /// join — and the stretch is how much a cross-section placed along that direction must widen
    /// so its silhouette stays constant across the joint. As the turn at a vertex sharpens
    /// toward a cusp (as where two boolean-combined curves meet almost tangentially), the
    /// bisector swings toward being perpendicular to the outgoing edge and the stretch diverges,
    /// so a joint sharp enough to exceed `maxMiterStretch` falls back to the outgoing edge's own
    /// normal with no stretch — the continuous limit of the miter as the turn sharpens further.
    /// (At the exact cusp, the bisector itself is undefined — the normalized sum collapses
    /// toward zero — which is the same fallback, so this subsumes that case too.) This must stay
    /// a pure function of the two edge vectors: the same vertex terminates one segment's ring
    /// and starts the next one's, and both need the identical joint to weld exactly.
    private func miterOffset(_ incoming: Vector2D, _ outgoing: Vector2D) -> (direction: Direction2D, stretch: Double) {
        let sum = incoming.normalized + outgoing.normalized
        let sumMagnitude = sum.magnitude
        guard sumMagnitude > 1e-9 else {
            return (Direction2D(outgoing).counterclockwiseNormal, 1)
        }
        let bisector = sum / sumMagnitude
        let alignment = bisector ⋅ outgoing.normalized
        guard alignment > 1 / Self.maxMiterStretch else {
            return (Direction2D(outgoing).counterclockwiseNormal, 1)
        }
        return (Direction2D(bisector).counterclockwiseNormal, 1 / alignment)
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
    private static let interfaceMargin = 5e-3

    /// The cross-section ring at one polygon vertex: maps a swept-region point (x, y) to
    /// (vertex + miterDirection * -x * stretch, y). The ring is computed once per vertex and
    /// shared by the segments on both sides, so their meeting faces have bit-identical vertices
    /// and the union welds them exactly — the seams can't leave coplanar-resolution debris the
    /// way independently trimmed prisms did.
    private func ringTransform(at vertex: Vector2D, incoming: Vector2D, outgoing: Vector2D) -> Transform3D {
        let (direction, stretch) = miterOffset(incoming, outgoing)
        let xAxis = -direction.unitVector * stretch
        return Transform3D([
            [xAxis.x, 0, -direction.unitVector.y, vertex.x],
            [xAxis.y, 0, direction.unitVector.x, vertex.y],
            [0, 1, 0, 0],
            [0, 0, 0, 1],
        ])
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
                .adding {
                    // Dip the wall-side margin strip below the profile's lower tip. Without
                    // this, the strip's bottom corner rests exactly on the wall line, and
                    // grazing contact resolves as unreliably as coincident faces do.
                    Rectangle(x: margin, y: margin * 2)
                        .translated(x: 0, y: -bounds.size.y - margin)
                }
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
                        let rings = vertices.indices.map { index in
                            ringTransform(
                                at: vertices[wrap: index],
                                incoming: vertices[wrap: index] - vertices[wrap: index - 1],
                                outgoing: vertices[wrap: index + 1] - vertices[wrap: index]
                            )
                        }
                        for index in vertices.indices {
                            Mesh(
                                extruding: regionPolygons,
                                along: [rings[index], rings[(index + 1) % rings.count]],
                                cacheName: "EdgeProfileSegment",
                                cacheParameters: regionPolygons, rings[index], rings[(index + 1) % rings.count]
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
            return CachedNodeTransformer<D3, D3>(body: tool, name: "EdgeProfileTool") { node, _, _ in node }
        }
    }
}
