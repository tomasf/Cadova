import Foundation

extension GeometryExpression2D {
    enum Kind: String, Codable, Hashable {
        case empty
        case shape
        case boolean
        case transform
        case convexHull
        case offset
        case projection
        case raw
    }
}

extension GeometryExpression2D: Hashable {
    func hash(into hasher: inout Hasher) {
        switch self {
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
            hasher.combine(amount)
            hasher.combine(joinStyle)
            hasher.combine(miterLimit)
            hasher.combine(segmentCount)
        case .projection(let body, let kind):
            hasher.combine(Kind.projection)
            hasher.combine(body)
            hasher.combine(kind)
        case .raw:
            hasher.combine(Kind.raw)
        }
    }

    static func == (lhs: GeometryExpression2D, rhs: GeometryExpression2D) -> Bool {
        switch (lhs, rhs) {
        case (.empty, .empty): true
        case let (.shape(a), .shape(b)): a == b
        case let (.boolean(ta, ca), .boolean(tb, cb)): ta == tb && ca == cb
        case let (.transform(a1, t1), .transform(a2, t2)): a1 == a2 && t1 == t2
        case let (.convexHull(a), .convexHull(b)): a == b
        case let (.offset(a1, aa, aj, am, asc), .offset(a2, ba, bj, bm, bsc)):
            a1 == a2 && aa == ba && aj == bj && am == bm && asc == bsc
        case let (.projection(a1, k1), .projection(a2, k2)): a1 == a2 && k1 == k2
        case (.raw, .raw): false

        case (.empty, _), (.shape, _), (.boolean, _), (.transform, _),
            (.convexHull, _), (.offset, _), (.projection, _), (.raw, _):
            false
        }
    }
}
