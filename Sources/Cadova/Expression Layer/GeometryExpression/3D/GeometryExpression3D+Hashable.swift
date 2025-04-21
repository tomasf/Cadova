import Foundation

extension GeometryExpression3D {
    enum Kind: String, Codable, Hashable {
        case empty
        case shape
        case boolean
        case transform
        case convexHull
        case extrusion
        case raw
        case tag
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

        case .raw (_, let source, let cacheKey):
            hasher.combine(Kind.raw)
            hasher.combine(source)
            hasher.combine(cacheKey)

        case .tag(let body, let key):
            hasher.combine(Kind.tag)
            hasher.combine(body)
            hasher.combine(key)
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
        case let (.raw(_, sa, keyA), .raw(_, sb, keyB)): keyA == keyB && sa == sb
        case let (.tag(ba, ua), .tag(bb, ub)): ba == bb && ua == ub

        case (.empty, _), (.shape, _), (.boolean, _), (.transform, _),
            (.convexHull, _), (.tag, _), (.extrusion, _), (.raw, _): false
        }
    }
}
