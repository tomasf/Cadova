import Foundation

extension GeometryNode: Equatable {
    static func == (lhs: GeometryNode, rhs: GeometryNode) -> Bool {
        switch (lhs.contents, rhs.contents) {
        case (.empty, .empty): true
        case let (.boolean(a, ta), .boolean(b, tb)): ta == tb && a == b
        case let (.transform(a1, t1), .transform(a2, t2)): a1 == a2 && t1 == t2
        case let (.convexHull(a), .convexHull(b)): a == b
        case let (.materialized(k1), .materialized(k2)): k1 == k2
        case let (.shape2D(a), .shape2D(b)): a == b
        case let (.offset(a1, aa, aj, am, asc), .offset(a2, ba, bj, bm, bsc)):
            a1 == a2 && aa.roundedForHash == ba.roundedForHash && aj == bj && am.roundedForHash == bm.roundedForHash && asc == bsc
        case let (.projection(a1, k1), .projection(a2, k2)): a1 == a2 && k1 == k2
        case let (.shape3D(a), .shape3D(b)): a == b
        case let (.applyMaterial(ba, aa), .applyMaterial(bb, ab)): ba == bb && aa == ab
        case let (.extrusion(a1, k1), .extrusion(a2, k2)): a1 == a2 && k1 == k2
        case let (.lazyUnion(ca), .lazyUnion(cb)): ca == cb

        case (.empty, _), (.boolean, _), (.transform, _), (.convexHull, _), (.materialized, _),
            (.shape2D, _), (.offset, _), (.projection, _),
            (.shape3D, _), (.applyMaterial, _), (.extrusion, _), (.lazyUnion, _):
            false
        }
    }
}

extension GeometryNode: Hashable {
    func hash(into hasher: inout Hasher) {
        switch contents {
        case .empty:
            hasher.combine(Kind.empty)
        case .boolean(let children, let type):
            hasher.combine(Kind.boolean)
            hasher.combine(type)
            hasher.combine(children)
        case .transform(let body, let transform):
            hasher.combine(Kind.transform)
            hasher.combine(body)
            hasher.combine(transform)
        case .convexHull(let body):
            hasher.combine(Kind.convexHull)
            hasher.combine(body)
        case .materialized(let key):
            hasher.combine(Kind.materialized)
            hasher.combine(key)
        case .shape2D(let shape):
            hasher.combine(Kind.shape2D)
            hasher.combine(shape)
        case .offset(let body, let amount, let joinStyle, let miterLimit, let segmentCount):
            hasher.combine(Kind.offset)
            hasher.combine(body)
            hasher.combine(amount.roundedForHash)
            hasher.combine(joinStyle)
            hasher.combine(miterLimit.roundedForHash)
            hasher.combine(segmentCount)
        case .projection(let body, let kind):
            hasher.combine(Kind.projection)
            hasher.combine(body)
            hasher.combine(kind)
        case .shape3D(let shape):
            hasher.combine(Kind.shape3D)
            hasher.combine(shape)
        case .applyMaterial(let body, let material):
            hasher.combine(Kind.applyMaterial)
            hasher.combine(body)
            hasher.combine(material)
        case .extrusion(let body, let type):
            hasher.combine(Kind.extrusion)
            hasher.combine(body)
            hasher.combine(type)
        case .lazyUnion(let children):
            hasher.combine(Kind.lazyUnion)
            hasher.combine(children)
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
        case rectangle, circle, polygon
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
        case .polygon(let points, let fillRule):
            hasher.combine(Kind.polygon)
            hasher.combine(points)
            hasher.combine(fillRule)
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.rectangle(a), .rectangle(b)): a == b
        case let (.circle(ra, sa), .circle(rb, sb)): ra.roundedForHash == rb.roundedForHash && sa == sb
        case let (.polygon(pa, fa), .polygon(pb, fb)): pa == pb && fa == fb

        case (.rectangle, _), (.circle, _), (.polygon, _): false
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
