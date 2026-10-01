import Foundation

extension OffsetCorners.PieceBuilder {
    /// A wedge at every kept sharp edge, between its moved faces; for bevel, the edge's region beyond its cut
    /// instead, and its own prism where neighbors' removals cross it
    func edgePieces() -> (grown: [OffsetCorners.Piece], removed: [OffsetCorners.Piece]) {
        var grown: [OffsetCorners.Piece] = []
        var removed: [OffsetCorners.Piece] = []

        for edge in convexEdges {
            let pa = vertices[edge.a], pb = vertices[edge.b]
            let along = (pb - pa).safelyNormalized
            let na = n[edge.faceA], nb = n[edge.faceB]
            let (kept, cut) = edgeCut(na, nb)
            guard kept else { continue }
            var ka = (along × na).safelyNormalized
            if ka ⋅ nb < 0 { ka = -ka }
            var kb = (along × nb).safelyNormalized
            if kb ⋅ na < 0 { kb = -kb }
            // Between the planes through the edge and each face normal
            let wedge = [OffsetCorners.Plane(-ka, through: pa), OffsetCorners.Plane(-kb, through: pa)]

            if style == .bevel, let cut {
                // The edge's region beyond the plane through the moved face edges
                // Only as far as the round offset of the edge's own faces reaches, within the amount of both: beyond,
                // as through a wall thinner than the amount, other faces decide
                var beyond = OffsetCorners.Piece(planes: wedge + [
                    OffsetCorners.Plane(-cut.normal, -(cut.normal ⋅ pa + cut.at)),
                    OffsetCorners.Plane(na, through: pa, beyond: r + tolerance), OffsetCorners.Plane(nb, through: pa, beyond: r + tolerance),
                ])
                for end in [edge.a, edge.b] {
                    let into = end == edge.a ? along : -along
                    // Ends across the edge, or where a chain of sharp edges bends, halfway around the bend, so the next
                    // edge's removal continues exactly where this one stops
                    var endNormal = into
                    let directions = wedgeDirectionsAt[end]
                    if let index = directions.firstIndex(where: { $0 ⋅ into > 1 - 1e-12 }), continuationAt[end][index] >= 0 {
                        endNormal = (into - directions[continuationAt[end][index]]).safelyNormalized
                    }
                    beyond.planes.append(OffsetCorners.Plane(-endNormal, through: vertices[end]))
                    // Another face at an end whose normal points along the edge into it covers the edge's region within
                    // the amount of its plane (its own offset reaches there): only remove beyond that. It has to reach
                    // under the region, though: a point of the region by the vertex must project onto it (or onto a face
                    // coplanar with it there).
                    let sample = vertices[end] + (na + nb) * (r / 2) + into * (r / 2)
                    func covers(_ f: Int) -> Bool {
                        fan[end].contains { g in
                            guard n[g] ⋅ n[f] >= 1 - 1e-9 else { return false }
                            let c = corners(g).map { vertices[$0] }
                            let q = sample - n[g] * (n[g] ⋅ (sample - c[0]))
                            return (0..<3).allSatisfy { k in
                                ((c[(k + 1) % 3] - c[k]) × (q - c[k])) ⋅ (n[g] * sign) >= -1e-12
                            }
                        }
                    }
                    for f in fan[end] where f != edge.faceA && f != edge.faceB && n[f] ⋅ into > 1e-6 && covers(f) {
                        beyond.planes.append(OffsetCorners.Plane(-n[f], -(n[f] ⋅ vertices[end] + r)))
                    }
                }
                beyond.bound(around: [pa, pb], margin: 2 * r)
                removed.append(beyond)

                // The edge's own bevel prism, to restore it where another edge's removal overlaps it: only by vertices
                // where another sharp edge meets it at an angle (as at a saddle). Along a chain of nearly parallel
                // edges, prisms and removals would leave razor-thin slivers between their slightly different planes.
                for end in [edge.a, edge.b] {
                    let into = end == edge.a ? along : -along
                    guard wedgeDirectionsAt[end].contains(where: { $0 ⋅ into < 0.99 && $0 ⋅ into > -0.5 }) else { continue }
                    var prism = OffsetCorners.Piece(planes: wedge + [
                        OffsetCorners.Plane(na, through: pa, beyond: r), OffsetCorners.Plane(nb, through: pa, beyond: r),
                        OffsetCorners.Plane(cut.normal, through: pa, beyond: cut.at),
                        OffsetCorners.Plane(-along, through: pa), OffsetCorners.Plane(along, through: pb),
                        OffsetCorners.Plane(into, through: vertices[end], beyond: 3 * r),
                    ])
                    prism.bound(around: [pa, pb], margin: 2 * r)
                    grown.append(prism)
                }
                continue
            }

            var piece = OffsetCorners.Piece(planes: wedge + [OffsetCorners.Plane(na, through: pa, beyond: r), OffsetCorners.Plane(nb, through: pa, beyond: r)])
            if let cut { piece.planes.append(OffsetCorners.Plane(cut.normal, through: pa, beyond: cut.at)) }
            // Ends reach just past the vertices, so the wedge overlaps whatever continues there. A convex corner's
            // planes and cuts also bound the whole wedge, which convexity makes harmless (the corner's cap fills that
            // anyway); a joint's or a saddle's wouldn't be.
            for end in [edge.a, edge.b] {
                let outward = end == edge.a ? -along : along
                piece.planes.append(OffsetCorners.Plane(outward, through: vertices[end], beyond: tolerance))
                let corner = cornersOf[end]
                guard corner.usable, !corner.isJoint else { continue }
                for f in corner.ring { piece.planes.append(OffsetCorners.Plane(n[f], through: vertices[end], beyond: r)) }
                if let at = corner.cut { piece.planes.append(OffsetCorners.Plane(corner.axis, through: vertices[end], beyond: at)) }
                for cut in cutsAt[end] { piece.planes.append(OffsetCorners.Plane(cut.normal, through: vertices[end], beyond: cut.at)) }
            }
            // The wedge's cross-section reaches its apex, the amount over the cosine of half the angle between the
            // normals, from the edge, or where it's cut, the amount over the cosine of a quarter of it; its ends
            // reach the tolerance past the vertices
            let halfAngle = Foundation.acos(min(max(na ⋅ nb, -1), 1)) / 2
            let apex = cut == nil ? r / cos(halfAngle) : r / cos(halfAngle / 2)
            piece.bound(around: [pa, pb], margin: apex * (1 + 1e-9) + tolerance)
            grown.append(piece)
        }
        return (grown, removed)
    }

    /// A cap at every corner and joint, under all moved planes around it; for bevel, the corner's region beyond its
    /// cuts instead
    func cornerPieces() -> (grown: [OffsetCorners.Piece], removed: [OffsetCorners.Piece]) {
        var grown: [OffsetCorners.Piece] = []
        var removed: [OffsetCorners.Piece] = []

        for v in vertices.indices where cornersOf[v].usable {
            let corner = cornersOf[v]
            let p = vertices[v]
            // The vertex's normal cone, which bounds its piece. Normals as far as a right angle from the axis make
            // no cone, only a half-space or more, and no miter.
            guard corner.widest < 1.5, let sides = OffsetCorners.coneSides(of: corner.ring.map { n[$0] }, around: corner.axis) else { continue }
            let cone = sides.map { OffsetCorners.Plane(-$0, through: p) }

            if style == .bevel {
                // Skipped where the corner makes no visible difference, where its faces spread so widely around the
                // axis that the cut would pass near or behind the vertex, at joints (whose edges' removals meet
                // halfway around the bend instead), and at crease points, whose cones are thin slabs
                guard r * (1 - cos(corner.widest)) >= tolerance, corner.widest <= 1.2, !corner.isJoint,
                      r * (1 - (max(0, 1 - corner.spread * corner.spread)).squareRoot()) >= tolerance,
                      let at = corner.cut
                else { continue }
                // The corner's region beyond its own plane, and beyond each cut of the edges meeting there
                for cut in cutsAt[v] + [OffsetCorners.Cut(normal: corner.axis, at: at)] {
                    var beyond = OffsetCorners.Piece(planes: cone + [OffsetCorners.Plane(-cut.normal, -(cut.normal ⋅ p + cut.at))]
                        + corner.ring.map { OffsetCorners.Plane(n[$0], through: p, beyond: r + tolerance) })
                    beyond.bound(around: [p], margin: 2 * r)
                    removed.append(beyond)
                }
                continue
            }

            guard r * (1 / cos(corner.widest) - 1) >= tolerance else { continue }
            var cap = OffsetCorners.Piece(planes: cone + corner.ring.map { OffsetCorners.Plane(n[$0], through: p, beyond: r) })
            cap.planes.append(OffsetCorners.Plane(corner.axis, through: p, beyond: corner.cut ?? limit * r))
            for cut in cutsAt[v] { cap.planes.append(OffsetCorners.Plane(cut.normal, through: p, beyond: cut.at)) }
            // Every point x of the cap lies in the cone of the ring's normals, x = Σ λ n, below every moved plane
            // (n·x <= r) and the axis cut (axis·x <= A), so |x|² = Σ λ n·x <= r Σ λ <= r A / cos(widest). A miter
            // is cut at r when r / cos(widest) passes the limit, so that stays within the limit times the amount.
            let cutAt = corner.cut ?? limit * r
            let margin = (r * cutAt / cos(corner.widest)).squareRoot() * (1 + 1e-9) + tolerance
            cap.bound(around: [p], margin: margin)
            grown.append(cap)
        }
        return (grown, removed)
    }
}
