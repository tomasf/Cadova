import Foundation

extension GeometryNode2D {
    enum Kind: String, Codable, Hashable {
        case empty
        case shape
        case boolean
        case transform
        case convexHull
        case offset
        case projection
        case materialized
    }
}

extension GeometryNode2D: Hashable {
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

        case .materialized (let cacheKey):
            hasher.combine(Kind.materialized)
            hasher.combine(cacheKey)
        }
    }

    public static func == (lhs: GeometryNode2D, rhs: GeometryNode2D) -> Bool {
        switch (lhs.contents, rhs.contents) {
        case (.empty, .empty): true
        case let (.shape(a), .shape(b)): a == b
        case let (.boolean(ta, ca), .boolean(tb, cb)): ta == tb && ca == cb
        case let (.transform(a1, t1), .transform(a2, t2)): a1 == a2 && t1 == t2
        case let (.convexHull(a), .convexHull(b)): a == b
        case let (.offset(a1, aa, aj, am, asc), .offset(a2, ba, bj, bm, bsc)):
            a1 == a2 && aa == ba && aj == bj && am == bm && asc == bsc
        case let (.projection(a1, k1), .projection(a2, k2)): a1 == a2 && k1 == k2
        case let (.materialized(keyA), .materialized(keyB)): keyA == keyB

        case (.empty, _), (.shape, _), (.boolean, _), (.transform, _),
            (.convexHull, _), (.offset, _), (.projection, _), (.materialized, _):
            false
        }
    }
}

extension GeometryNode2D.PrimitiveShape {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .rectangle(let size):
            hasher.combine(Kind.rectangle)
            hasher.combine(size)

        case .circle(let radius, let segmentCount):
            hasher.combine(Kind.circle)
            hasher.combine(radius.roundedForHash)
            hasher.combine(segmentCount)

        case .polygon(let points, let fillRule):
            hasher.combine(Kind.polygon)
            hasher.combine(points)
            hasher.combine(fillRule)
        }
    }

    public static func ==(_ lhs: Self, _ rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.rectangle(a), .rectangle(b)):
            a == b

        case let (.circle(ra, sa), .circle(rb, sb)):
            ra.roundedForHash == rb.roundedForHash && sa == sb

        case let (.polygon(pa, fa), .polygon(pb, fb)):
            pa == pb && fa == fb

        case (.rectangle, _), (.circle, _), (.polygon, _):
            false
        }
    }
}

extension GeometryNode2D.Projection {
    private enum Kind: Int {
        case full, slice
    }

    public static func ==(lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.full, .full):
            true
        case let (.slice(z1), .slice(z2)):
            z1.roundedForHash == z2.roundedForHash
        case (.full, _), (.slice, _):
            false
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .full:
            hasher.combine(Kind.full)
        case .slice(let z):
            hasher.combine(Kind.slice)
            hasher.combine(z.roundedForHash)
        }
    }

}
