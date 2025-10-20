import Foundation

extension GeometryNode.Contents: Equatable {
    static func == (lhs: GeometryNode.Contents, rhs: GeometryNode.Contents) -> Bool {
        switch (lhs, rhs) {
        case (.empty, .empty): true
        case let (.boolean(a, ta), .boolean(b, tb)): ta == tb && a == b
        case let (.transform(a1, t1), .transform(a2, t2)): a1 == a2 && t1 == t2
        case let (.convexHull(a), .convexHull(b)): a == b
        case let (.refine(n1, l1), .refine(n2, l2)): n1 == n2 && l1 == l2
        case let (.simplify(n1, t1), .simplify(n2, t2)): n1 == n2 && t1 == t2

        case let (.materialized(k1), .materialized(k2)): k1 == k2
        case let (.shape2D(a), .shape2D(b)): a == b
        case let (.offset(a1, aa, aj, am, asc), .offset(a2, ba, bj, bm, bsc)):
            a1 == a2 && aa.roundedForHash == ba.roundedForHash && aj == bj && am.roundedForHash == bm.roundedForHash && asc == bsc
        case let (.projection(a1, k1), .projection(a2, k2)): a1 == a2 && k1 == k2
        case let (.shape3D(a), .shape3D(b)): a == b
        case let (.applyMaterial(ba, aa), .applyMaterial(bb, ab)): ba == bb && aa == ab
        case let (.extrusion(a1, k1), .extrusion(a2, k2)): a1 == a2 && k1 == k2
        case let (.trim(a1, p1), .trim(a2, p2)): a1 == a2 && p1 == p2

        default: false
        }
    }
}

extension GeometryNode.Contents: Hashable {
    func hash(into hasher: inout Hasher) {
        switch self {
        case .empty:
            hasher.combine(GeometryNode.Kind.empty)
        case .boolean(let children, let type):
            hasher.combine(GeometryNode.Kind.boolean)
            hasher.combine(type)
            hasher.combine(children)
        case .transform(let body, let transform):
            hasher.combine(GeometryNode.Kind.transform)
            hasher.combine(body)
            hasher.combine(transform)
        case .convexHull(let body):
            hasher.combine(GeometryNode.Kind.convexHull)
            hasher.combine(body)
        case .refine(let body, let edgeLength):
            hasher.combine(GeometryNode.Kind.refine)
            hasher.combine(body)
            hasher.combine(edgeLength)
        case .simplify(let body, let tolerance):
            hasher.combine(GeometryNode.Kind.simplify)
            hasher.combine(body)
            hasher.combine(tolerance)
        case .materialized(let key):
            hasher.combine(GeometryNode.Kind.materialized)
            hasher.combine(key)
        case .shape2D(let shape):
            hasher.combine(GeometryNode.Kind.shape2D)
            hasher.combine(shape)
        case .offset(let body, let amount, let joinStyle, let miterLimit, let segmentCount):
            hasher.combine(GeometryNode.Kind.offset)
            hasher.combine(body)
            hasher.combine(amount.roundedForHash)
            hasher.combine(joinStyle)
            hasher.combine(miterLimit.roundedForHash)
            hasher.combine(segmentCount)
        case .projection(let body, let kind):
            hasher.combine(GeometryNode.Kind.projection)
            hasher.combine(body)
            hasher.combine(kind)
        case .shape3D(let shape):
            hasher.combine(GeometryNode.Kind.shape3D)
            hasher.combine(shape)
        case .applyMaterial(let body, let material):
            hasher.combine(GeometryNode.Kind.applyMaterial)
            hasher.combine(body)
            hasher.combine(material)
        case .extrusion(let body, let type):
            hasher.combine(GeometryNode.Kind.extrusion)
            hasher.combine(body)
            hasher.combine(type)
        case .trim(let body, let plane):
            hasher.combine(GeometryNode.Kind.trim)
            hasher.combine(body)
            hasher.combine(plane)
        }
    }
}

extension GeometryNode.Projection {
    private enum Kind: String {
        case full, slice
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.full, .full): true
        case let (.slice(a), .slice(b)): a.roundedForHash == b.roundedForHash

        case (.full, _), (.slice, _): false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .full:
            hasher.combine(Kind.full)
        case .slice(let z):
            hasher.combine(Kind.slice)
            hasher.combine(z.roundedForHash)
        }
    }
}

extension GeometryNode.Extrusion {
    private enum Kind: String {
        case linear, rotational
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.linear(h1, t1, d1, s1), .linear(h2, t2, d2, s2)):
            h1.roundedForHash == h2.roundedForHash && t1 == t2 && d1 == d2 && s1 == s2
        case let (.rotational(a1, s1), .rotational(a2, s2)):
            a1 == a2 && s1 == s2

        case (.linear, _), (.rotational, _): false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .linear(let height, let twist, let divisions, let scaleTop):
            hasher.combine(Kind.linear)
            hasher.combine(height.roundedForHash)
            hasher.combine(twist)
            hasher.combine(divisions)
            hasher.combine(scaleTop)
        case .rotational(let angle, let segments):
            hasher.combine(Kind.rotational)
            hasher.combine(angle)
            hasher.combine(segments)
        }
    }
}

extension GeometryNode.PrimitiveShape2D {
    private enum Kind: String {
        case rectangle, circle, polygon, convexHull
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .rectangle(let size):
            hasher.combine(Kind.rectangle)
            hasher.combine(size)
        case .circle(let radius, let segments):
            hasher.combine(Kind.circle)
            hasher.combine(radius.roundedForHash)
            hasher.combine(segments)
        case .polygons(let list, let fillRule):
            hasher.combine(Kind.polygon)
            hasher.combine(list)
            hasher.combine(fillRule)
        case .convexHull(let points):
            hasher.combine(Kind.convexHull)
            hasher.combine(points)
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.rectangle(a), .rectangle(b)): a == b
        case let (.circle(ra, sa), .circle(rb, sb)): ra.roundedForHash == rb.roundedForHash && sa == sb
        case let (.polygons(la, fa), .polygons(lb, fb)): la == lb && fa == fb
        case let (.convexHull(pa), .convexHull(pb)): pa == pb

        case (.rectangle, _), (.circle, _), (.polygons, _), (.convexHull, _): false
        }
    }
}

extension GeometryNode.PrimitiveShape3D {
    private enum Kind: String {
        case box, sphere, cylinder, convexHull, mesh
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .box(let size):
            hasher.combine(Kind.box)
            hasher.combine(size)
        case .sphere(let radius, let segmentCount):
            hasher.combine(Kind.sphere)
            hasher.combine(radius.roundedForHash)
            hasher.combine(segmentCount)
        case .cylinder(let bottomRadius, let topRadius, let height, let segmentCount):
            hasher.combine(Kind.cylinder)
            hasher.combine(bottomRadius.roundedForHash)
            hasher.combine(topRadius.roundedForHash)
            hasher.combine(height.roundedForHash)
            hasher.combine(segmentCount)
        case .convexHull(let points):
            hasher.combine(Kind.convexHull)
            hasher.combine(points)
        case .mesh(let mesh):
            hasher.combine(Kind.mesh)
            hasher.combine(mesh)
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.box(a), .box(b)): a == b
        case let (.sphere(ra, sa), .sphere(rb, sb)): ra.roundedForHash == rb.roundedForHash && sa == sb
        case let (.cylinder(ba, ta, ha, sa), .cylinder(bb, tb, hb, sb)):
            ba.roundedForHash == bb.roundedForHash && ta.roundedForHash == tb.roundedForHash && ha.roundedForHash == hb.roundedForHash && sa == sb
        case let (.convexHull(pa), .convexHull(pb)): pa == pb
        case let (.mesh(ma), .mesh(mb)): ma == mb

        case (.box, _), (.sphere, _), (.cylinder, _), (.convexHull, _), (.mesh, _): false
        }
    }
}
