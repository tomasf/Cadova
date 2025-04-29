import Foundation

extension GeometryExpression3D {
    enum Kind: String, Codable, Hashable {
        case empty
        case shape
        case boolean
        case transform
        case convexHull
        case extrusion
        case materialized
        case applyMaterial
        case lazyUnion
    }
}

extension GeometryExpression3D: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch contents {
        case .empty:
            hasher.combine(Kind.empty)

        case .shape(let primitive):
            hasher.combine(Kind.shape)
            hasher.combine(primitive)

        case .boolean(let type, let children):
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

        case .extrusion(let body, let kind):
            hasher.combine(Kind.extrusion)
            hasher.combine(body)
            hasher.combine(kind)

        case .materialized (let cacheKey):
            hasher.combine(Kind.materialized)
            hasher.combine(cacheKey)

        case .applyMaterial(let body, let application):
            hasher.combine(Kind.applyMaterial)
            hasher.combine(body)
            hasher.combine(application)

        case .lazyUnion(let children):
            hasher.combine(Kind.lazyUnion)
            hasher.combine(children)
        }
    }

    public static func == (lhs: GeometryExpression3D, rhs: GeometryExpression3D) -> Bool {
        switch (lhs.contents, rhs.contents) {
        case (.empty, .empty): true
        case let (.shape(a), .shape(b)): a == b
        case let (.boolean(ta, ca), .boolean(tb, cb)): ta == tb && ca == cb
        case let (.transform(a1, t1), .transform(a2, t2)): a1 == a2 && t1 == t2
        case let (.convexHull(a), .convexHull(b)): a == b
        case let (.extrusion(a1, k1), .extrusion(a2, k2)): a1 == a2 && k1 == k2
        case let (.materialized(keyA), .materialized(keyB)): keyA == keyB
        case let (.applyMaterial(ba, aa), .applyMaterial(bb, ab)): ba == bb && aa == ab
        case let (.lazyUnion(ca), .lazyUnion(cb)): ca == cb

        case (.empty, _), (.shape, _), (.boolean, _), (.transform, _), (.lazyUnion, _),
            (.convexHull, _), (.applyMaterial, _), (.extrusion, _), (.materialized, _): false
        }
    }
}

extension GeometryExpression3D.PrimitiveShape {
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.box(a), .box(b)):
            return a == b

        case let (.sphere(ra, sa), .sphere(rb, sb)):
            return ra.roundedForHash == rb.roundedForHash && sa == sb

        case let (.cylinder(ba, ta, ha, sa), .cylinder(bb, tb, hb, sb)):
            return ba.roundedForHash == bb.roundedForHash &&
            ta.roundedForHash == tb.roundedForHash &&
            ha.roundedForHash == hb.roundedForHash &&
            sa == sb

        case let (.convexHull(pa), .convexHull(pb)):
            return pa == pb

        case let (.mesh(ma), .mesh(mb)):
            return ma == mb

        case (.box, _), (.sphere, _), (.cylinder, _), (.convexHull, _), (.mesh, _):
            return false
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .box(let size):
            hasher.combine(Kind.box)
            hasher.combine(size)

        case .sphere(let radius, let segmentCount):
            hasher.combine(Kind.sphere)
            hasher.combine(radius.roundedForHash)
            hasher.combine(segmentCount)

        case .cylinder(let bottom, let top, let height, let segments):
            hasher.combine(Kind.cylinder)
            hasher.combine(bottom.roundedForHash)
            hasher.combine(top.roundedForHash)
            hasher.combine(height.roundedForHash)
            hasher.combine(segments)

        case .convexHull(let points):
            hasher.combine(Kind.convexHull)
            hasher.combine(points)

        case .mesh(let mesh):
            hasher.combine(Kind.mesh)
            hasher.combine(mesh)
        }
    }
}

extension GeometryExpression3D.Extrusion {
    private enum Kind: Int {
        case linear, rotational
    }

    public static func ==(lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.linear(h1, t1, d1, s1), .linear(h2, t2, d2, s2)):
            h1.roundedForHash == h2.roundedForHash &&
            t1 == t2 && d1 == d2 && s1 == s2

        case let (.rotational(a1, s1), .rotational(a2, s2)):
            a1 == a2 && s1 == s2

        case (.linear, _), (.rotational, _):
            false
        }
    }

    public func hash(into hasher: inout Hasher) {
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
