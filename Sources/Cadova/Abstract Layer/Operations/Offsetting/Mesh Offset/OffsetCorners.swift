import Foundation

/// The corners of an offset with sharp joins (miter, square or bevel), as convex pieces around the round offset.
///
/// The round offset is the base. Miter and square add convex pieces for the corners it rounds off: a wedge at every
/// convex edge, between the moved faces, and a cap at every convex vertex, under all moved planes around it, and
/// where a chain of sharp edges bends. Square cuts both at the offset distance along the bisector, and miter falls
/// back to that beyond the miter limit. Bevel lies inside the round offset instead: it removes each edge's and
/// corner's region beyond the plane through the moved face edges, and restores an edge's own prism where a
/// neighbor's removal crosses it. A corner is cut by its own plane and by the cuts of all edges meeting there, so
/// corners and edges agree.
///
/// Each piece is an intersection of half-spaces, so its largest plane distance is continuous, changes no faster than
/// position, and is zero exactly on its boundary; unions and differences take minimums and maximums. Grown pieces
/// overlap where they meet, so no seam between them reads as surface. An inward offset does all of this on the
/// inside-out mesh. Pieces that change the surface by less than the tolerance are left out, so a tessellated curve
/// stays round instead of turning into a lattice of creases.
internal final class OffsetCorners: @unchecked Sendable {
    let field: MeshDistanceField
    let amount: Double
    let sign: Double
    let grown: PieceSet
    let removed: PieceSet
    /// Pieces reach no farther than this from the surface
    let reach: Double

    struct Plane {
        let normal: Vector3D
        let offset: Double   // inside where normal·x - offset <= 0

        init(_ normal: Vector3D, _ offset: Double) {
            self.normal = normal
            self.offset = offset
        }

        init(_ normal: Vector3D, through point: Vector3D, beyond: Double = 0) {
            self.init(normal, normal ⋅ point + beyond)
        }
    }

    struct Piece {
        var planes: [Plane] = []
        var lower = Vector3D.zero
        var upper = Vector3D.zero

        /// Clips the piece to the box around the points, grown by a margin, so it's contained in its box by
        /// construction (which skipping pieces by box distance relies on). The margin holds the part of the piece
        /// that can reach the surface.
        mutating func bound(around points: [Vector3D], margin: Double) {
            lower = points[0]; upper = points[0]
            for p in points { lower = .min(lower, p); upper = .max(upper, p) }
            lower = lower - margin
            upper = upper + margin
            planes.append(Plane(Vector3D(1, 0, 0), upper.x)); planes.append(Plane(Vector3D(-1, 0, 0), -lower.x))
            planes.append(Plane(Vector3D(0, 1, 0), upper.y)); planes.append(Plane(Vector3D(0, -1, 0), -lower.y))
            planes.append(Plane(Vector3D(0, 0, 1), upper.z)); planes.append(Plane(Vector3D(0, 0, -1), -lower.z))
        }
    }

    init(field: MeshDistanceField, amount: Double, style: LineJoinStyle, miterLimit: Double, tolerance: Double) {
        self.field = field
        self.amount = abs(amount)
        sign = amount >= 0 ? 1 : -1
        let r = abs(amount)
        // Only miters use the limit; square and bevel corners stay within about 1.5 times the amount
        let limit = style == .miter ? max(miterLimit, 1) : 1.5
        reach = limit * r + r + 1e-9
        let pieces = Self.pieces(field: field, r: r, sign: sign, style: style, limit: limit, tolerance: tolerance)
        grown = PieceSet(pieces.grown)
        removed = PieceSet(pieces.removed)
    }

    struct Corner {
        var ring: [Int] = []
        var axis = Vector3D.zero
        var widest = 0.0
        /// How far the normals stray from their best-fitting great circle: nearly none makes a crease point, not a
        /// corner
        var spread = 0.0
        var usable = false
        var isJoint = false
        var cut: Double? = nil
    }

    struct Cut {
        let normal: Vector3D
        let at: Double
    }

    static func pieces(field: MeshDistanceField, r: Double, sign: Double, style: LineJoinStyle, limit: Double, tolerance: Double) -> (grown: [Piece], removed: [Piece]) {
        guard style != .round, r > 0 else { return ([], []) }
        let vertices = field.vertices
        let faceCount = field.faceCount
        // Normals toward the side the offset grows into
        let n = (0..<faceCount).map { field.faceNormal($0) * sign }
        func corners(_ face: Int) -> [Int] { let f = field.face(face); return [f.0, f.1, f.2] }
        func directedKey(_ a: Int, _ b: Int) -> UInt64 { UInt64(a) << 32 | UInt64(b) }

        var faceOfDirected: [UInt64: Int] = [:]
        var fan = [[Int]](repeating: [], count: vertices.count)
        for face in 0..<faceCount {
            let c = corners(face)
            for k in 0..<3 {
                faceOfDirected[directedKey(c[k], c[(k + 1) % 3])] = face
                fan[c[k]].append(face)
            }
        }
        func opposite(_ face: Int, _ a: Int, _ b: Int) -> Int { corners(face).first { $0 != a && $0 != b } ?? a }

        // Edge convexity toward the offset
        var concave = Set<UInt64>()
        var convexEdges: [(a: Int, b: Int, faceA: Int, faceB: Int)] = []
        for face in 0..<faceCount {
            let c = corners(face)
            for k in 0..<3 {
                let a = c[k], b = c[(k + 1) % 3]
                guard a < b, let other = faceOfDirected[directedKey(b, a)] else { continue }
                let side = n[face] ⋅ (vertices[opposite(other, a, b)] - vertices[a])
                let scale = 1e-9 * (vertices[b] - vertices[a]).magnitude
                if side > scale { concave.insert(MeshDistanceField.edgeKey(a, b)) }
                if side < -scale && !field.isSuspect(face) && !field.isSuspect(other) { convexEdges.append((a, b, face, other)) }
            }
        }

        // Each edge's cut (square, miter past the limit, bevel), and whether the edge is sharp enough to keep
        func edgeCut(_ na: Vector3D, _ nb: Vector3D) -> (kept: Bool, cut: Cut?) {
            let halfAngle = Foundation.acos(min(max(na ⋅ nb, -1), 1)) / 2
            let bisector = (na + nb).safelyNormalized
            switch style {
            case .bevel:
                return (r * (1 - cos(halfAngle)) >= tolerance, Cut(normal: bisector, at: r * cos(halfAngle)))
            case .square:
                return (r * (1 / cos(halfAngle) - 1) >= tolerance, Cut(normal: bisector, at: r))
            default:
                let exceeds = r / cos(halfAngle) > limit * r
                return (r * (1 / cos(halfAngle) - 1) >= tolerance, exceeds ? Cut(normal: bisector, at: r) : nil)
            }
        }

        // Finishes a corner from its ring of faces: its axis, how wide its faces spread, and where it's cut
        func finish(_ corner: inout Corner) {
            // Averaged over distinct planes: a face split into several triangles mustn't pull the axis its way
            var distinct: [Vector3D] = []
            for f in corner.ring where !distinct.contains(where: { $0 ⋅ n[f] > 1 - 1e-9 }) { distinct.append(n[f]) }
            corner.axis = distinct.reduce(Vector3D.zero, +).safelyNormalized
            // Fewer than three distinct planes make no cone, only a flat fan with coincident sides
            guard distinct.count >= 3 else { return }
            var matrix = (0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
            for d in distinct {
                matrix.0 += d.x * d.x; matrix.1 += d.x * d.y; matrix.2 += d.x * d.z
                matrix.3 += d.y * d.y; matrix.4 += d.y * d.z; matrix.5 += d.z * d.z
            }
            let eigen = PlaneFit.eigenDecomposition(matrix)
            let flattest = eigen.vector((0..<3).min { eigen.value($0) < eigen.value($1) }!)
            corner.spread = distinct.map { abs($0 ⋅ flattest) }.max() ?? 0
            corner.widest = min(corner.ring.map { Foundation.acos(min(max(n[$0] ⋅ corner.axis, -1), 1)) }.max() ?? 0, 1.5)
            corner.usable = true
            let apex = r / cos(corner.widest)
            switch style {
            case .square: corner.cut = r
            case .miter: corner.cut = apex > limit * r ? r : nil
            case .bevel: corner.cut = r * (corner.ring.map { corner.axis ⋅ n[$0] }.min() ?? 1)
            case .round: break
            }
        }

        // Corners: convex vertices (no concave edge around them), with all their faces in ring order
        var cornersOf = [Corner](repeating: Corner(), count: vertices.count)
        for v in vertices.indices where fan[v].count >= 3 {
            var corner = Corner()
            var face = fan[v][0]
            var closed = false
            for _ in 0...fan[v].count {
                corner.ring.append(face)
                let c = corners(face)
                let k = c.firstIndex(of: v)!
                guard let next = faceOfDirected[directedKey(v, c[(k + 2) % 3])] else { break }
                if next == fan[v][0] { closed = true; break }
                face = next
            }
            guard closed, corner.ring.count == fan[v].count else { continue }
            var anyConcave = false, defective = false
            for f in corner.ring {
                if field.isSuspect(f) { defective = true }
                let c = corners(f)
                for k in 0..<3 where c[k] == v || c[(k + 1) % 3] == v {
                    if concave.contains(MeshDistanceField.edgeKey(c[k], c[(k + 1) % 3])) { anyConcave = true }
                }
            }
            guard !anyConcave, !defective else { continue }
            finish(&corner)
            cornersOf[v] = corner
        }

        // Corners are cut by every cut of the edges meeting there, so a corner and the edges running into it agree
        var cutsAt = [[Cut]](repeating: [], count: vertices.count)
        // The kept edges at each vertex: their faces, and their directions away from it
        var wedgeFacesAt = [[Int]](repeating: [], count: vertices.count)
        var wedgeDirectionsAt = [[Vector3D]](repeating: [], count: vertices.count)
        for edge in convexEdges {
            let (kept, cut) = edgeCut(n[edge.faceA], n[edge.faceB])
            guard kept else { continue }
            for (end, other) in [(edge.a, edge.b), (edge.b, edge.a)] {
                if let cut { cutsAt[end].append(cut) }
                wedgeDirectionsAt[end].append((vertices[other] - vertices[end]).safelyNormalized)
                for f in [edge.faceA, edge.faceB] where !wedgeFacesAt[end].contains(f) { wedgeFacesAt[end].append(f) }
            }
        }

        // Sharp edges continuing each other through a vertex, paired straightest first
        var continuationAt = [[Int]](repeating: [], count: vertices.count)
        for v in vertices.indices where !wedgeDirectionsAt[v].isEmpty {
            let directions = wedgeDirectionsAt[v]
            var continuation = [Int](repeating: -1, count: directions.count)
            var pairs: [(Double, Int, Int)] = []
            for i in directions.indices {
                for j in (i + 1)..<directions.count where directions[i] ⋅ directions[j] < -0.5 {
                    pairs.append((directions[i] ⋅ directions[j], i, j))
                }
            }
            for (_, i, j) in pairs.sorted(by: { $0.0 < $1.0 }) where continuation[i] < 0 && continuation[j] < 0 {
                continuation[i] = j
                continuation[j] = i
            }
            continuationAt[v] = continuation
        }

        // Joints: where a chain of sharp edges bends, two wedges continue nearly straight through a vertex that isn't a
        // corner. Their ends leave a gap on the outside of the bend, which a cap over the wedges' faces fills.
        // Elsewhere, such as a saddle where edges meet at an angle, the edges' own regions already overlap.
        for v in vertices.indices where !cornersOf[v].usable && wedgeDirectionsAt[v].count == 2 {
            guard wedgeDirectionsAt[v][0] ⋅ wedgeDirectionsAt[v][1] <= -0.5 else { continue }
            var joint = Corner()
            // Ordered by angle around the faces' mean normal, so consecutive normals bound their cone
            let mean = wedgeFacesAt[v].reduce(Vector3D.zero) { $0 + n[$1] }.safelyNormalized
            let first = n[wedgeFacesAt[v][0]]
            let off = first - mean * (first ⋅ mean)
            guard off.magnitude > 1e-9 else { continue }
            let reference = off.safelyNormalized
            let side = mean × reference
            joint.ring = wedgeFacesAt[v].sorted {
                Foundation.atan2(n[$0] ⋅ side, n[$0] ⋅ reference) < Foundation.atan2(n[$1] ⋅ side, n[$1] ⋅ reference)
            }
            finish(&joint)
            guard joint.usable else { continue }
            joint.isJoint = true
            cornersOf[v] = joint
        }

        var grown: [Piece] = []
        var removed: [Piece] = []

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
            let wedge = [Plane(-ka, through: pa), Plane(-kb, through: pa)]

            if style == .bevel, let cut {
                // The edge's region beyond the plane through the moved face edges
                // Only as far as the round offset of the edge's own faces reaches, within the amount of both: beyond,
                // as through a wall thinner than the amount, other faces decide
                var beyond = Piece(planes: wedge + [
                    Plane(-cut.normal, -(cut.normal ⋅ pa + cut.at)),
                    Plane(na, through: pa, beyond: r + tolerance), Plane(nb, through: pa, beyond: r + tolerance),
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
                    beyond.planes.append(Plane(-endNormal, through: vertices[end]))
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
                        beyond.planes.append(Plane(-n[f], -(n[f] ⋅ vertices[end] + r)))
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
                    var prism = Piece(planes: wedge + [
                        Plane(na, through: pa, beyond: r), Plane(nb, through: pa, beyond: r),
                        Plane(cut.normal, through: pa, beyond: cut.at),
                        Plane(-along, through: pa), Plane(along, through: pb),
                        Plane(into, through: vertices[end], beyond: 3 * r),
                    ])
                    prism.bound(around: [pa, pb], margin: 2 * r)
                    grown.append(prism)
                }
                continue
            }

            var piece = Piece(planes: wedge + [Plane(na, through: pa, beyond: r), Plane(nb, through: pa, beyond: r)])
            if let cut { piece.planes.append(Plane(cut.normal, through: pa, beyond: cut.at)) }
            // Ends reach just past the vertices, so the wedge overlaps whatever continues there. A convex corner's
            // planes and cuts also bound the whole wedge, which convexity makes harmless (the corner's cap fills that
            // anyway); a joint's or a saddle's wouldn't be.
            for end in [edge.a, edge.b] {
                let outward = end == edge.a ? -along : along
                piece.planes.append(Plane(outward, through: vertices[end], beyond: tolerance))
                let corner = cornersOf[end]
                guard corner.usable, !corner.isJoint else { continue }
                for f in corner.ring { piece.planes.append(Plane(n[f], through: vertices[end], beyond: r)) }
                if let at = corner.cut { piece.planes.append(Plane(corner.axis, through: vertices[end], beyond: at)) }
                for cut in cutsAt[end] { piece.planes.append(Plane(cut.normal, through: vertices[end], beyond: cut.at)) }
            }
            // The wedge's cross-section reaches its apex, the amount over the cosine of half the angle between the
            // normals, from the edge, or where it's cut, the amount over the cosine of a quarter of it; its ends
            // reach the tolerance past the vertices
            let halfAngle = Foundation.acos(min(max(na ⋅ nb, -1), 1)) / 2
            let apex = cut == nil ? r / cos(halfAngle) : r / cos(halfAngle / 2)
            piece.bound(around: [pa, pb], margin: apex * (1 + 1e-9) + tolerance)
            grown.append(piece)
        }

        for v in vertices.indices where cornersOf[v].usable {
            let corner = cornersOf[v]
            let p = vertices[v]
            // The vertex's normal cone, which bounds its piece. Normals as far as a right angle from the axis make
            // no cone, only a half-space or more, and no miter.
            guard corner.widest < 1.5, let sides = Self.coneSides(of: corner.ring.map { n[$0] }, around: corner.axis) else { continue }
            let cone = sides.map { Plane(-$0, through: p) }

            if style == .bevel {
                // Skipped where the corner makes no visible difference, where its faces spread so widely around the
                // axis that the cut would pass near or behind the vertex, at joints (whose edges' removals meet
                // halfway around the bend instead), and at crease points, whose cones are thin slabs
                guard r * (1 - cos(corner.widest)) >= tolerance, corner.widest <= 1.2, !corner.isJoint,
                      r * (1 - (max(0, 1 - corner.spread * corner.spread)).squareRoot()) >= tolerance,
                      let at = corner.cut
                else { continue }
                // The corner's region beyond its own plane, and beyond each cut of the edges meeting there
                for cut in cutsAt[v] + [Cut(normal: corner.axis, at: at)] {
                    var beyond = Piece(planes: cone + [Plane(-cut.normal, -(cut.normal ⋅ p + cut.at))]
                        + corner.ring.map { Plane(n[$0], through: p, beyond: r + tolerance) })
                    beyond.bound(around: [p], margin: 2 * r)
                    removed.append(beyond)
                }
                continue
            }

            guard r * (1 / cos(corner.widest) - 1) >= tolerance else { continue }
            var cap = Piece(planes: cone + corner.ring.map { Plane(n[$0], through: p, beyond: r) })
            cap.planes.append(Plane(corner.axis, through: p, beyond: corner.cut ?? limit * r))
            for cut in cutsAt[v] { cap.planes.append(Plane(cut.normal, through: p, beyond: cut.at)) }
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

    /// The inward normals of the planes (through the origin) bounding the cone the normals span: the sides between
    /// neighbors on their convex hull, seen from the axis. Ring order would do for a vertex whose normals turn one
    /// way around it, but where they fold back, as on crumpled slivers, its planes bound nothing. Nil where the
    /// normals lie on or nearly on one great circle, which spans no cone.
    static func coneSides(of normals: [Vector3D], around axis: Vector3D) -> [Vector3D]? {
        // Projected onto the plane touching the unit sphere at the axis, cones are convex polygons
        let helper = abs(axis.x) < 0.9 ? Vector3D(1, 0, 0) : Vector3D(0, 1, 0)
        let u = (axis × helper).safelyNormalized, w = axis × u
        typealias Projected = (x: Double, y: Double, normal: Vector3D)
        var points: [Projected] = normals.compactMap { normal in
            let height = normal ⋅ axis
            guard height > 1e-9 else { return nil }
            return ((normal ⋅ u) / height, (normal ⋅ w) / height, normal)
        }
        guard points.count == normals.count else { return nil }
        points.sort { $0.x != $1.x ? $0.x < $1.x : $0.y < $1.y }
        // Monotone chain, counterclockwise, dropping points on the hull's sides
        func turn(_ o: Projected, _ a: Projected, _ b: Projected) -> Double {
            (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
        }
        var hull: [Projected] = []
        for pass in 0..<2 {
            let start = hull.count
            for point in pass == 0 ? points : points.reversed() {
                while hull.count >= start + 2 && turn(hull[hull.count - 2], hull[hull.count - 1], point) <= 1e-12 { hull.removeLast() }
                hull.append(point)
            }
            hull.removeLast()
        }
        guard hull.count >= 3 else { return nil }
        // Each side faces the rest of the hull. Where the rest lies nearly in its plane, the cone is too thin to
        // tell which way that is, and too thin to add anything but a sliver: a crease point, like normals on one
        // great circle.
        var sides: [Vector3D] = []
        for k in hull.indices {
            let side = (hull[k].normal × hull[(k + 1) % hull.count].normal).safelyNormalized
            let farthest = hull.map { side ⋅ $0.normal }.max { abs($0) < abs($1) } ?? 0
            guard abs(farthest) >= 1e-3 else { return nil }
            sides.append(farthest < 0 ? -side : side)
        }
        return sides
    }

    /// The offset function with sharp joins (negative inside the offset solid), its gradient, and the face closest
    /// to p (a hint for nearby queries). Outward: min(max(round, -removed), grown), removing first so grown pieces
    /// restore what removing takes from neighbors, and never removing the solid itself. Inward: the same on the
    /// complement, negated.
    ///
    /// With a cap, the value is only exact where its magnitude is within the cap; beyond it, it's only known to lie
    /// beyond on the same side, which lets the piece searches stop much sooner.
    func evaluate(at p: Vector3D, hint: Int?, cap: Double = .infinity) -> (value: Double, gradient: Vector3D, face: Int) {
        // Pieces reach no farther than their reach from the surface, so beyond the amount, the reach and the cap from
        // the mesh, the value is beyond the cap: only look for the mesh that near
        let closest = field.closest(to: p, hint: hint, within: cap.isFinite ? amount + reach + cap : .infinity)
        guard closest.face >= 0 else { return (cap, .zero, hint ?? -1) }
        let distance = closest.distanceSquared.squareRoot()
        let inside = field.isInside(p, closest: closest)
        let toward = p - closest.point
        // Distance from the side the offset grows into
        let solidGradient = (distance > 0 ? toward * ((inside ? -1 : 1) / distance) : closest.pseudonormal.safelyNormalized) * sign
        let solid = (inside ? -distance : distance) * sign
        var value = solid - amount
        var gradient = solidGradient
        // Each search only looks for pieces that would change the value: removed ones below minus it, grown ones
        // below it. That bounds the searches far more tightly than the pieces' reach.
        let removal = removed.value(at: p, reach: min(reach, -value, cap))
        if -removal.value > value { value = -removal.value; gradient = -removal.gradient }
        let growth = grown.value(at: p, reach: min(reach, value, cap))
        if growth.value < value { value = growth.value; gradient = growth.gradient }
        if solid < value { value = solid; gradient = solidGradient }
        return (value * sign, gradient * sign, closest.face)
    }

    /// Whether any piece's box comes within radius of p. Where none does, grown pieces are positive and removed
    /// ones negative throughout, so the offset has the round offset's surface there.
    func mayAffect(_ p: Vector3D, radius: Double) -> Bool {
        grown.hasBox(within: radius, of: p) || removed.hasBox(within: radius, of: p)
    }
}
