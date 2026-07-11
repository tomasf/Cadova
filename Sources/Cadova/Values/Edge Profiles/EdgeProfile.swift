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

    /// The most a miter trim is allowed to stretch away from the vertex it's anchored to, as a
    /// factor of the profile's own size — mirrors `EdgeToolSweep.maxMiterStretch`, which guards
    /// the same instability in the newer edge-shaping system.
    private static let maxMiterStretch = 8.0

    /// The direction of the miter trim line at a polygon vertex, given the incoming and outgoing
    /// edge vectors (in that order).
    ///
    /// Ordinarily this is the normal of the two edges' bisector — the standard miter join. But as
    /// the turn at a vertex sharpens toward a cusp (as where two boolean-combined curves meet
    /// almost tangentially), the bisector swings toward being perpendicular to the outgoing edge,
    /// and the trim plane it defines has to travel proportionally farther along that edge before
    /// it actually crosses it — the miter "stretches". Past a turn sharp enough that the stretch
    /// would exceed `maxMiterStretch`, the trim plane can land far beyond the next vertex,
    /// producing a malformed, often folded-back sliver in the cutting tool instead of a bounded
    /// local joint. Falling back to the outgoing edge's own normal past that point is the
    /// continuous limit of the miter as the turn sharpens further, so the trim degrades to a
    /// plain perpendicular cut instead of swinging unboundedly. (At the exact cusp, the bisector
    /// itself is undefined — the normalized sum collapses toward zero — which is the same
    /// fallback, so this subsumes that case too.) This must stay a pure function of the two edge
    /// vectors: the same vertex is trimmed once as a segment's end and once as the next segment's
    /// start, and both calls need to agree.
    private func miterLineNormal(_ incoming: Vector2D, _ outgoing: Vector2D) -> Direction2D {
        let sum = incoming.normalized + outgoing.normalized
        let sumMagnitude = sum.magnitude
        guard sumMagnitude > 1e-9 else {
            return Direction2D(outgoing).counterclockwiseNormal
        }
        let bisector = sum / sumMagnitude
        let alignment = bisector ⋅ outgoing.normalized
        guard alignment > 1 / Self.maxMiterStretch else {
            return Direction2D(outgoing).counterclockwiseNormal
        }
        return Direction2D(bisector).counterclockwiseNormal
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
    private func droppingDegenerateVertices(_ vertices: [Vector2D]) -> [Vector2D] {
        guard vertices.count > 3 else { return vertices }
        var result: [Vector2D] = [vertices[0]]
        for vertex in vertices.dropFirst() {
            if (vertex - result[result.count - 1]).magnitude > Self.degenerateEdgeLength {
                result.append(vertex)
            }
        }
        if result.count > 1, (result[0] - result[result.count - 1]).magnitude <= Self.degenerateEdgeLength {
            result.removeLast()
        }
        return result
    }

    /// How far the cut cross-section is grown past the profile's own exact silhouette, for the
    /// subtraction case only.
    ///
    /// At a genuinely sharp corner sitting close to a run of micro-segments (left behind by
    /// `rounded(insideRadius:outsideRadius:)` or similar offset-based operations, then clipped by
    /// a later boolean), the miter joints on a short segment between them can have too little
    /// room to meet cleanly, leaving a thin sliver standing the height of the profile right at
    /// that seam — even though neither joint's own miter stretch is extreme in isolation, and no
    /// single vertex looks wrong on inspection. Rather than chase the exact numerical mechanism
    /// (attempted and inconclusive — see project memory), grow the swept cross-section by this
    /// margin so a sliver of this scale ends up inside the removed material instead of standing
    /// proud of it. Far below fabrication tolerance, so it costs nothing on ordinary geometry.
    ///
    /// Validated (repeatedly, deterministically) only for `type == .subtraction`, which is what
    /// `cuttingEdgeProfile`/`topEdge:` use. The forming/addition case sweeps the same boundary
    /// in reversed order (see `rawVertices` below) and empirically does NOT benefit from the
    /// same margin — growing made it measurably worse, and shrinking didn't cleanly fix it
    /// either; the mechanism there isn't understood yet. Do not extend this margin to the
    /// addition case without separately re-deriving and validating it — see project memory.
    private static let sliverSwallowMargin = 0.02

    func followingEdge(of shape: any Geometry2D, type: EnvironmentValues.Operation) -> any Geometry3D {
        readingNegativeShape { rawNegativeShape, profileSize in
            let negativeShape = type == .subtraction
                ? rawNegativeShape.offset(amount: Self.sliverSwallowMargin, style: .round)
                : rawNegativeShape
            let unitProfile = negativeShape.extruded(height: 1.0)
                .rotated(x: 90°, z: -90°)
                .translated(
                    x: 1,
                    y: type == .subtraction ? -1e-2 : -1e-6,
                    z: type == .subtraction ? 1e-4 : 0
                )

            shape.simplified().readingConcrete { crossSection in
                crossSection.polygonList().polygons.mapUnion { polygon in
                    // Only needs to be long enough that the miter planes at both ends are
                    // guaranteed to fully cross the prism's local cross-section regardless of
                    // how sharp the turn is — bounded by maxMiterStretch, so scale from the
                    // profile's own size rather than the whole polygon's bounding box. The old
                    // bounding-box-diagonal overshoot could reach 100+mm on a modest profile,
                    // so on a curve with many short segments (a large-radius fillet, densely
                    // tessellated) every segment's oversized prism reached far outside its own
                    // local region and could spatially collide with prisms from a completely
                    // unrelated part of the same curve once unioned, leaving a bridging sliver
                    // where the two overlapped.
                    let overshoot = profileSize.magnitude * (Self.maxMiterStretch + 2)
                    let rawVertices = type == .subtraction ? polygon.vertices : Array(polygon.vertices.reversed())
                    let vertices = droppingDegenerateVertices(rawVertices)
                    for index in vertices.indices {
                        let a = vertices[wrap: index - 1]
                        let b = vertices[wrap: index]
                        let c = vertices[wrap: index + 1]
                        let d = vertices[wrap: index + 2]

                        let ba = b - a
                        let cb = c - b
                        let dc = d - c

                        let startLine = Line(point: b, direction: miterLineNormal(ba, cb))
                        let endLine = Line(point: c, direction: miterLineNormal(cb, dc))

                        unitProfile.scaled(x: cb.magnitude + 2 * overshoot)
                            .translated(x: -overshoot)
                            .rotated(z: b.angle(to: c))
                            .translated(b, z: 0)
                            .trimmed(along: Plane(line: startLine).offset(-1e-6))
                            .trimmed(along: Plane(line: endLine).flipped.offset(-1e-6))
                    }
                }
            }
        }
    }
}
