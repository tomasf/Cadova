import Foundation

internal extension EdgeProfile {
    /// How close the path's own curvature may come to the profile's depth before the tool is built
    /// from offsets rather than swept per-vertex (see `offsetTool`).
    ///
    /// Well below `1.0` the per-vertex sweep is exact, and it's the cheaper of the two — it builds
    /// a mesh roughly two thirds the size, since the offset construction has to resample every
    /// section to a common ring — so it stays the default. As the ratio approaches `1.0` the
    /// sweep's rings start crowding together near the curve's center of curvature: first merely
    /// ill-conditioned, where near-tangent surfaces get resolved inconsistently from run to run,
    /// then outright invalid past `1.0`, where the rings cross and the segment prisms fold through
    /// themselves.
    ///
    /// Measured on a rounded rectangle: the sweep folds badly at `1.00` and `1.04` (30-37 folded
    /// edges every run), and is still *intermittently* bad at `1.19` and `1.25`, where repeated
    /// builds of identical input gave 5/0/5 and 1/6/1. From `1.52` up it came back clean six runs
    /// out of six, at every ratio tested through `2.50`. This sits at the near edge of that clean
    /// band. Sampling has to be repeated to mean anything here — a two-run sample at `1.25` looked
    /// clean before a third run found six folds.
    private static let offsetToolCurvatureRatio = 1.5

    /// The tightest radius of curvature along `polygon`, considering only vertices where the
    /// profile's inward direction faces the center of curvature.
    ///
    /// That's the only case where reaching inward can overshoot: offsetting *away* from your own
    /// center of curvature never self-intersects no matter how far it goes, which is why an outside
    /// corner accepts a fillet of any size while an inside one doesn't. The radius comes from the
    /// circumcircle through the previous, current, and next vertex, computed relative to the
    /// current vertex — translating all three by the same amount leaves the circumcenter's offset
    /// from any one of them unchanged, and the current vertex lies on that circle, so the offset's
    /// own magnitude is the radius.
    static func tightestInwardRadius(of polygon: SimplePolygon) -> Double {
        let vertices = polygon.vertices
        guard vertices.count >= 3 else { return .infinity }

        var tightest = Double.infinity
        for index in vertices.indices {
            let incoming = vertices[wrap: index] - vertices[wrap: index - 1]
            let outgoing = vertices[wrap: index + 1] - vertices[wrap: index]
            // A positive cross product is a left turn, and for the counterclockwise outer contours
            // used here that's a convex corner — the one whose center of curvature lies inward.
            let twiceCross = 2 * (incoming.x * outgoing.y - incoming.y * outgoing.x)
            guard twiceCross > 1e-12 else { continue }

            let inMagSquared = incoming ⋅ incoming
            let outMagSquared = outgoing ⋅ outgoing
            let center = Vector2D(
                x: -(inMagSquared * outgoing.y + outMagSquared * incoming.y) / twiceCross,
                y: (inMagSquared * outgoing.x + outMagSquared * incoming.x) / twiceCross
            )
            tightest = min(tightest, center.magnitude)
        }
        return tightest
    }

    /// How far the tool reaches inward from the edge, sampled at every height where the profile's
    /// own outline has a vertex, ordered from the profile's deep end up to the edge face.
    ///
    /// The profile occupies x ∈ [-depth, 0] and y ∈ [-height, 0], with the material it *keeps*
    /// hugging the far corner, so at any height the cut surface is the profile's rightmost point
    /// and everything from there to the wall at x = 0 is removed. Sampling only at vertex heights
    /// is exact, not an approximation: the outline is a polygon, so it's straight between them, and
    /// so is the interpolation between the corresponding offsets.
    ///
    /// Returns `nil` for a profile this model can't describe — one whose depth doesn't grow
    /// monotonically toward the edge face. An undercut profile removes a band that floats away from
    /// the wall instead of one anchored to it, which isn't a plain erosion at all; those keep the
    /// swept construction.
    static func inwardDepthSamples(of polygons: [SimplePolygon]) -> [(height: Double, depth: Double)]? {
        let vertices = polygons.flatMap(\.vertices).sorted { $0.y < $1.y }
        guard vertices.count >= 3 else { return nil }

        var samples: [(height: Double, depth: Double)] = []
        for vertex in vertices {
            let depth = -vertex.x
            if let last = samples.last, abs(last.height - vertex.y) < 1e-9 {
                samples[samples.count - 1].depth = min(last.depth, depth)
            } else {
                samples.append((height: vertex.y, depth: depth))
            }
        }

        guard samples.count >= 2 else { return nil }
        for (lower, upper) in zip(samples, samples.dropFirst()) where upper.depth < lower.depth - 1e-9 {
            return nil
        }
        return samples
    }

    /// A cutting tool built from the shape's own inward offsets rather than by sweeping a
    /// cross-section along its outline.
    ///
    /// The two constructions agree wherever both are valid, but they arrive there differently. The
    /// sweep moves each outline vertex along its own miter ray, which is exact only while those
    /// rays stay clear of each other; where the outline curves tightly enough that they cross, the
    /// swept surface folds through itself and no amount of care in the sweep can recover, because
    /// the shape it's trying to describe genuinely isn't a sweep of a fixed cross-section anymore.
    ///
    /// Offsets have no such limit. At every height the material the fillet leaves behind is exactly
    /// the shape eroded by the profile's depth at that height — the classic rolling-ball fillet,
    /// whose horizontal sections are erosions by construction — and an erosion stays well defined
    /// however tight the curvature gets, resolving a corner too tight to hold the profile into a
    /// sharp one instead of an inverted one. Skinning between consecutive erosions reproduces the
    /// profile's own faceting between the sample heights.
    ///
    /// The skin is built here rather than handed to `Loft` because the ring-to-ring correspondence
    /// has to be chosen deliberately. `Loft` resamples every section by arc length between detected
    /// corners, and an eroding corner changes which of those it has: while the arc survives it's
    /// smooth, with no turn sharp enough to register, and once it collapses it's a sharp vertex that
    /// does. Sections on either side of that transition are then resampled by different rules, so
    /// corresponding vertices slide around the contour from one ring to the next and the surface
    /// between them ripples — visibly, in a slicer. Matching each ring to the widest one by closest
    /// point instead follows the offset direction, which is the direction the fillet's own surface
    /// actually runs, and stays put as the corner collapses: the points that have nowhere left to go
    /// pile up on the collapsed corner, which is exactly the ridge the surface has there.
    ///
    /// The tool starts where the fillet has already drawn `margin` clear of the wall, not at the
    /// tangent line where it meets it.
    ///
    /// Approaching the wall asymptotically is what a fillet does geometrically, but it's poison for
    /// the boolean that has to cut it: an erosion by a few microns is a contour that runs alongside
    /// the body's own outline without sharing a single vertex with it, and resolving two surfaces
    /// that close together — but not actually coincident — is exactly the ill-conditioned case that
    /// leaves slivers behind. (The swept construction sidesteps this by anchoring its rings on the
    /// outline's own vertices, so its version of the same tangency is vertex-exact.) Beginning a
    /// margin in, the tool's lowest face crosses the wall cleanly instead of grazing it, at the cost
    /// of a step the size of the margin itself, where the fillet is at its shallowest.
    static func offsetTool(
        shape: any Geometry2D,
        outline: D2.Concrete,
        samples: [(height: Double, depth: Double)],
        profileSize: Vector2D,
        margin: Double,
        segmentation: Segmentation
    ) -> any Geometry3D {
        let clear = samples.filter { $0.depth > margin }
        let base = clear.first?.height ?? -profileSize.y
        // The widest level sits a margin below the rest and a margin proud of the tool's own outer
        // wall, so the tool is strictly empty where the fillet runs out rather than tapering into a
        // face shared with the body.
        let levels: [(height: Double, offset: Double)] =
            [(base - margin, margin * 2)] + clear.map { ($0.height, -$0.depth) }

        let rings = levels.map { level in
            outline
                .offset(
                    amount: level.offset,
                    joinType: .round,
                    circularSegments: segmentation.segmentCount(circleRadius: abs(level.offset))
                )
                .polygonList()
        }

        return shape
            .offset(amount: margin, style: .miter)
            .extruded(height: margin - base)
            .translated(z: base)
            .subtracting {
                skin(rings: rings, heights: levels.map(\.height))
            }
    }

    /// A closed mesh through `rings`, each placed at the matching height, with every ring matched
    /// point for point against the first.
    private static func skin(rings: [SimplePolygonList], heights: [Double]) -> any Geometry3D {
        guard let reference = rings.first, rings.count >= 2 else { return Empty() }

        // Each ring is re-expressed with one point per point of the reference ring, so consecutive
        // rings connect without any resampling in between. Contours are matched by centroid: an
        // erosion moves a contour inward but never far, and separate contours (the cells of a tray,
        // say) stay far apart compared to how much any one of them shifts.
        let matched: [[[Vector2D]]] = rings.map { ring in
            reference.polygons.map { referenceContour in
                guard let contour = ring.polygons.min(by: {
                    ($0.centroid - referenceContour.centroid).magnitude
                        < ($1.centroid - referenceContour.centroid).magnitude
                }), contour.vertices.count >= 3 else {
                    return referenceContour.vertices
                }
                return referenceContour.vertices.map { closestPoint(to: $0, on: contour.vertices) }
            }
        }

        var vertices: [Vector3D] = []
        var faces: [[Int]] = []
        var ringStart: [[Int]] = []

        for (ringIndex, ring) in matched.enumerated() {
            var starts: [Int] = []
            for contour in ring {
                starts.append(vertices.count)
                vertices.append(contentsOf: contour.map { Vector3D($0.x, $0.y, heights[ringIndex]) })
            }
            ringStart.append(starts)
        }

        for ringIndex in 0..<(matched.count - 1) {
            for (contourIndex, contour) in matched[ringIndex].enumerated() {
                let lower = ringStart[ringIndex][contourIndex]
                let upper = ringStart[ringIndex + 1][contourIndex]
                for i in contour.indices {
                    let j = (i + 1) % contour.count
                    faces.append([lower + i, lower + j, upper + j])
                    faces.append([lower + i, upper + j, upper + i])
                }
            }
        }

        // Caps, triangulated from the rings' own points so they share vertices with the walls.
        // Points that piled up on a collapsed corner make degenerate triangles here, which the weld
        // pass drops along with the duplicates that caused them.
        for (ringIndex, winding) in [(0, false), (matched.count - 1, true)] {
            let list = SimplePolygonList(matched[ringIndex].map { SimplePolygon($0) })
            for triangle in list.triangulated() {
                let index = { (vertex: SimplePolygonList.Vertex) in
                    ringStart[ringIndex][vertex.0] + vertex.1
                }
                let face = [index(triangle.0), index(triangle.1), index(triangle.2)]
                faces.append(winding ? face : face.reversed())
            }
        }

        let points = vertices
        return Mesh(faces: faces, name: "EdgeProfileOffsetSkin", cacheParameters: [points, faces]) {
            points[$0]
        }
    }

    /// The point on the closed polyline `contour` nearest to `point`, projected onto its edges
    /// rather than snapped to a vertex, so a ring reads off its match at full resolution instead of
    /// quantized to wherever the offset happened to put its vertices.
    private static func closestPoint(to point: Vector2D, on contour: [Vector2D]) -> Vector2D {
        var best = contour[0]
        var bestDistance = Double.infinity
        for i in contour.indices {
            let a = contour[i]
            let b = contour[(i + 1) % contour.count]
            let edge = b - a
            let lengthSquared = edge ⋅ edge
            let t = lengthSquared > 0 ? min(max(((point - a) ⋅ edge) / lengthSquared, 0), 1) : 0
            let candidate = a + edge * t
            let distance = (candidate - point).magnitude
            if distance < bestDistance {
                bestDistance = distance
                best = candidate
            }
        }
        return best
    }

    /// Whether `polygons` curve tightly enough, relative to `profileDepth`, that the swept
    /// construction should give way to the offset one.
    static func needsOffsetTool(polygons: [SimplePolygon], profileDepth: Double) -> Bool {
        guard profileDepth > 1e-9 else { return false }
        let tightest = polygons.map { tightestInwardRadius(of: $0) }.min() ?? .infinity
        return tightest < profileDepth * offsetToolCurvatureRatio
    }

    /// Whether the shape survives its own deepest erosion with its structure intact — every
    /// contour still present, none split apart or swallowed.
    ///
    /// `Loft` interpolates between sections by matching them up contour for contour, so it can
    /// only describe a stack whose pieces correspond throughout. Erosion doesn't always oblige: a
    /// feature narrower than the profile is deep erodes away entirely, and a waisted one pinches
    /// through the middle and splits in two. Both are legitimate shapes to ask for a fillet on, and
    /// both are outside what this construction can say, so they stay with the swept one rather than
    /// being handed to a loft that would quietly mismatch them.
    ///
    /// Comparing counts at the deepest erosion is enough to cover the intermediate ones: erosions
    /// are nested, so a contour that vanishes or splits at any depth has already done so by the
    /// deepest, and holes count here too — `polygonList` flattens them in alongside the outer
    /// contours.
    static func erosionPreservesStructure(original: [SimplePolygon], deepest: [SimplePolygon]) -> Bool {
        original.count == deepest.count && !deepest.contains { $0.vertices.count < 3 }
    }
}

