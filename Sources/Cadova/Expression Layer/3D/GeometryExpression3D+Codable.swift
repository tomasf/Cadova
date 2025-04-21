import Foundation
import Manifold3D

extension GeometryExpression3D: Codable {
    enum CodingKeys: String, CodingKey {
        case kind // Which geometry kind?
        case type // Subtype within kind
        case primitive
        case children
        case body
        case transform
        case crossSection
        case mesh
        case key
        case source
        case cacheKey
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

        case .extrusion(let body, let type):
            try container.encode(Kind.extrusion, forKey: .kind)
            try container.encode(body, forKey: .crossSection)
            try container.encode(type, forKey: .type)

        case .raw(let manifold, let source, let cacheKey):
            try container.encode(Kind.raw, forKey: .kind)
            try container.encode(manifold.meshGL(), forKey: .mesh)
            try container.encode(source, forKey: .source)
            try container.encode(cacheKey, forKey: .cacheKey)

        case .tag (let body, let key):
            try container.encode(Kind.tag, forKey: .kind)
            try container.encode(body, forKey: .body)
            try container.encode(key, forKey: .key)
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
            let children = try container.decode([GeometryExpression3D].self, forKey: .children)
            self.init(.boolean(children, type: type))
        case .transform:
            let body = try container.decode(GeometryExpression3D.self, forKey: .body)
            let transform = try container.decode(AffineTransform3D.self, forKey: .transform)
            self.init(.transform(body, transform: transform))
        case .convexHull:
            let body = try container.decode(GeometryExpression3D.self, forKey: .body)
            self.init(.convexHull(body))
        case .extrusion:
            let body = try container.decode(GeometryExpression2D.self, forKey: .crossSection)
            let type = try container.decode(Extrusion.self, forKey: .type)
            self.init(.extrusion(body, type: type))
        case .raw:
            let meshGL = try container.decode(MeshGL.self, forKey: .mesh)
            let source = try container.decode(GeometryExpression3D.self, forKey: .source)
            let cacheKey = try container.decode(OpaqueKey.self, forKey: .cacheKey)
            self.init(.raw(try Manifold(meshGL), source: source, cacheKey: cacheKey))
        case .tag:
            let body = try container.decode(GeometryExpression3D.self, forKey: .body)
            let key = try container.decode(OpaqueKey.self, forKey: .key)
            self.init(.tag(body, key: key))
        }
    }
}
