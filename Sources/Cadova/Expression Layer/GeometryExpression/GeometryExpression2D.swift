import Foundation
import Manifold3D

indirect enum GeometryExpression2D: Sendable {
    case empty
    case shape (PrimitiveShape)
    case boolean ([GeometryExpression2D], type: BooleanOperationType)
    case transform (GeometryExpression2D, transform: AffineTransform2D)
    case convexHull (GeometryExpression2D)
    case offset (GeometryExpression2D, amount: Double, joinStyle: LineJoinStyle, miterLimit: Double, segmentCount: Int)
    case projection (GeometryExpression3D, kind: Projection)
    case raw (CrossSection)

    enum PrimitiveShape: Hashable, Sendable, Codable {
        case rectangle (size: Vector2D)
        case circle (radius: Double, segmentCount: Int)
        case polygon (points: [Vector2D], fillRule: FillRule)
    }

    enum Projection: Hashable, Sendable, Codable {
        case full
        case slice (z: Double)
    }
}

extension GeometryExpression2D {
    var isCacheable: Bool {
        switch self {
        case .empty, .shape:
            return true

        case .raw:
            return false

        case .boolean(let children, _):
            return children.allSatisfy(\.isCacheable)

        case .transform(let body, _), .convexHull(let body), .offset(let body, _, _, _, _):
            return body.isCacheable

        case .projection(let body, _):
            return body.isCacheable
        }
    }
    
    func evaluate(in context: EvaluationContext) async -> CrossSection {
        switch self {
        case .empty:
            .empty

        case .shape (let shape):
            shape.evaluate()

        case .boolean (let members, let type):
            await CrossSection.boolean(type.manifoldRepresentation, with: context.geometries(for: members))

        case .transform (let expression, let transform):
            await context.geometry(for: expression).transform(transform)

        case .convexHull (let expression):
            await context.geometry(for: expression).hull()

        case .offset (let expression, let amount, let joinStyle, let miterLimit, let segmentCount):
            await context.geometry(for: expression)
                .offset(amount: amount, joinType: joinStyle.manifoldRepresentation, miterLimit: miterLimit, circularSegments: segmentCount)

        case .projection (let expression, let projection):
            switch projection {
            case .full:
                await context.geometry(for: expression).projection()
            case .slice (let z):
                await context.geometry(for: expression).slice(at: z)
            }

        case .raw (let crossSection):
            crossSection
        }
    }
}

extension GeometryExpression2D.PrimitiveShape {
    func evaluate() -> CrossSection {
        switch self {
        case .rectangle (let size):
            CrossSection.square(size: size)
        case .circle (let radius, let segmentCount):
            CrossSection.circle(radius: radius, segmentCount: segmentCount)
        case .polygon (let points, let fillRule):
            CrossSection(polygons: [Manifold3D.Polygon(vertices: points)], fillRule: fillRule.primitive)
        }
    }
}

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
        case (.empty, .empty): return true
        case let (.shape(a), .shape(b)): return a == b
        case let (.boolean(ta, ca), .boolean(tb, cb)): return ta == tb && ca == cb
        case let (.transform(a1, t1), .transform(a2, t2)): return a1 == a2 && t1 == t2
        case let (.convexHull(a), .convexHull(b)): return a == b
        case let (.offset(a1, aa, aj, am, asc), .offset(a2, ba, bj, bm, bsc)):
            return a1 == a2 && aa == ba && aj == bj && am == bm && asc == bsc
        case let (.projection(a1, k1), .projection(a2, k2)): return a1 == a2 && k1 == k2
        case (.raw, .raw): return false
        default: return false
        }
    }
}
