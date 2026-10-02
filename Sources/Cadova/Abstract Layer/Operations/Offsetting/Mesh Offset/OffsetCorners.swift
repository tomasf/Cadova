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
        var builder = PieceBuilder(field: field, r: r, sign: sign, style: style, limit: limit, tolerance: tolerance)
        return builder.build()
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
