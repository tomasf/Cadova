import Foundation
import Manifold3D

extension GeometryExpression2D: Codable {
    enum CodingKeys: String, CodingKey {
        case kind // Which geometry kind?
        case type // Local type within kind
        case primitive
        case children
        case body
        case transform
        case amount
        case joinStyle
        case miterLimit
        case segmentCount
        case crossSection
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .empty:
            try container.encode(Kind.empty, forKey: .kind)

        case .shape(let primitive):
            try container.encode(Kind.shape, forKey: .kind)
            try container.encode(primitive, forKey: .primitive)

        case .boolean(let children, let type):
            try container.encode(Kind.boolean, forKey: .kind)
            try container.encode(type, forKey: .type)
            try container.encode(children, forKey: .children)

        case .transform(let body, let transform):
            try container.encode(Kind.transform, forKey: .kind)
            try container.encode(body, forKey: .body)
            try container.encode(transform, forKey: .transform)

        case .convexHull(let body):
            try container.encode(Kind.convexHull, forKey: .kind)
            try container.encode(body, forKey: .body)

        case .offset(let body, let amount, let joinStyle, let miterLimit, let segmentCount):
            try container.encode(Kind.offset, forKey: .kind)
            try container.encode(body, forKey: .body)
            try container.encode(amount, forKey: .amount)
            try container.encode(joinStyle, forKey: .joinStyle)
            try container.encode(miterLimit, forKey: .miterLimit)
            try container.encode(segmentCount, forKey: .segmentCount)

        case .projection(let body, let type):
            try container.encode(Kind.projection, forKey: .kind)
            try container.encode(body, forKey: .body)
            try container.encode(type, forKey: .type)

        case .raw(let crossSection, _):
            try container.encode(Kind.raw, forKey: .kind)
            try container.encode(crossSection.polygons(), forKey: .crossSection)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        switch kind {
        case .empty:
            self = .empty
        case .shape:
            self = .shape(try container.decode(PrimitiveShape.self, forKey: .primitive))
        case .boolean:
            let type = try container.decode(BooleanOperationType.self, forKey: .type)
            let children = try container.decode([GeometryExpression2D].self, forKey: .children)
            self = .boolean(children, type: type)
        case .transform:
            let body = try container.decode(GeometryExpression2D.self, forKey: .body)
            let transform = try container.decode(AffineTransform2D.self, forKey: .transform)
            self = .transform(body, transform: transform)
        case .convexHull:
            let body = try container.decode(GeometryExpression2D.self, forKey: .body)
            self = .convexHull(body)
        case .offset:
            self = .offset(
                try container.decode(GeometryExpression2D.self, forKey: .body),
                amount: try container.decode(Double.self, forKey: .amount),
                joinStyle: try container.decode(LineJoinStyle.self, forKey: .joinStyle),
                miterLimit: try container.decode(Double.self, forKey: .miterLimit),
                segmentCount: try container.decode(Int.self, forKey: .segmentCount)
            )
        case .projection:
            let body = try container.decode(GeometryExpression3D.self, forKey: .body)
            let type = try container.decode(Projection.self, forKey: .type)
            self = .projection(body, type: type)
        case .raw:
            let polygons = try container.decode([Manifold3D.Polygon].self, forKey: .crossSection)
            self = .raw(CrossSection(polygons: polygons, fillRule: .nonZero), key: nil)
        }
    }
}
