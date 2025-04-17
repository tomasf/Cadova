import Foundation

extension GeometryExpression3D {
    enum Kind: String, Codable, Hashable {
        case empty
        case shape
        case boolean
        case transform
        case convexHull
        case material
        case extrusion
        case raw
    }
}

extension GeometryExpression3D: Hashable {
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

        case .material(let body, let material):
            hasher.combine(Kind.material)
            hasher.combine(body)
            hasher.combine(material)

        case .extrusion(let body, let kind):
            hasher.combine(Kind.extrusion)
            hasher.combine(body)
            hasher.combine(kind)

        case .raw:
            hasher.combine(Kind.raw)
        }
    }

    static func == (lhs: GeometryExpression3D, rhs: GeometryExpression3D) -> Bool {
        switch (lhs, rhs) {
        case (.empty, .empty): true
        case let (.shape(a), .shape(b)): a == b
        case let (.boolean(ta, ca), .boolean(tb, cb)): ta == tb && ca == cb
        case let (.transform(a1, t1), .transform(a2, t2)): a1 == a2 && t1 == t2
        case let (.convexHull(a), .convexHull(b)): a == b
        case let (.material(a1, m1), .material(a2, m2)): a1 == a2 && m1 == m2
        case let (.extrusion(a1, k1), .extrusion(a2, k2)): a1 == a2 && k1 == k2
        case (.raw, .raw): false

        case (.empty, _), (.shape, _), (.boolean, _), (.transform, _),
            (.convexHull, _), (.material, _), (.extrusion, _), (.raw, _): false
        }
    }
}
