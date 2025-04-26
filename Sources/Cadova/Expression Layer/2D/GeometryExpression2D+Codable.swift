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
        case cacheKey
        case source
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch contents {
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

        case .raw(let crossSection, let cacheKey):
            try container.encode(Kind.raw, forKey: .kind)
            try container.encode(crossSection.polygons(), forKey: .crossSection)
            try container.encode(cacheKey, forKey: .cacheKey)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        switch kind {
        case .empty:
            self.init(.empty)
        case .shape:
            self.init(.shape(try container.decode(PrimitiveShape.self, forKey: .primitive)))
        case .boolean:
            let type = try container.decode(BooleanOperationType.self, forKey: .type)
            let children = try container.decode([GeometryExpression2D].self, forKey: .children)
            self.init(.boolean(children, type: type))
        case .transform:
            let body = try container.decode(GeometryExpression2D.self, forKey: .body)
            let transform = try container.decode(AffineTransform2D.self, forKey: .transform)
            self.init(.transform(body, transform: transform))
        case .convexHull:
            let body = try container.decode(GeometryExpression2D.self, forKey: .body)
            self.init(.convexHull(body))
        case .offset:
            self.init(.offset(
                try container.decode(GeometryExpression2D.self, forKey: .body),
                amount: try container.decode(Double.self, forKey: .amount),
                joinStyle: try container.decode(LineJoinStyle.self, forKey: .joinStyle),
                miterLimit: try container.decode(Double.self, forKey: .miterLimit),
                segmentCount: try container.decode(Int.self, forKey: .segmentCount)
            ))
        case .projection:
            let body = try container.decode(GeometryExpression3D.self, forKey: .body)
            let type = try container.decode(Projection.self, forKey: .type)
            self.init(.projection(body, type: type))
        case .raw:
            let polygons = try container.decode([ManifoldPolygon].self, forKey: .crossSection)
            let cacheKey = try container.decode(OpaqueKey.self, forKey: .cacheKey)
            self.init(.raw(
                CrossSection(polygons: polygons, fillRule: .nonZero), cacheKey: cacheKey
            ))
        }
    }
}

extension GeometryExpression2D.PrimitiveShape {
    enum Kind: String, Codable, Hashable {
        case rectangle
        case circle
        case polygon
    }

    enum CodingKeys: String, CodingKey {
        case kind
        case size
        case radius
        case segmentCount
        case points
        case fillRule
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        switch kind {
        case .rectangle:
            let size = try container.decode(Vector2D.self, forKey: .size)
            self = .rectangle(size: size)
        case .circle:
            let radius = try container.decode(Double.self, forKey: .radius)
            let segmentCount = try container.decode(Int.self, forKey: .segmentCount)
            self = .circle(radius: radius, segmentCount: segmentCount)
        case .polygon:
            let points = try container.decode([Vector2D].self, forKey: .points)
            let fillRule = try container.decode(FillRule.self, forKey: .fillRule)
            self = .polygon(points: points, fillRule: fillRule)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .rectangle(let size):
            try container.encode(Kind.rectangle, forKey: .kind)
            try container.encode(size, forKey: .size)
        case .circle(let radius, let segmentCount):
            try container.encode(Kind.circle, forKey: .kind)
            try container.encode(radius, forKey: .radius)
            try container.encode(segmentCount, forKey: .segmentCount)
        case .polygon(let points, let fillRule):
            try container.encode(Kind.polygon, forKey: .kind)
            try container.encode(points, forKey: .points)
            try container.encode(fillRule, forKey: .fillRule)
        }
    }
}
