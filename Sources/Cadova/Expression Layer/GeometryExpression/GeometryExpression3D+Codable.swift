import Foundation
import Manifold3D

extension GeometryExpression3D: Codable {
    enum CodingKeys: String, CodingKey {
        case kind // Which geometry kind?
        case type // Local type within kind
        case primitive
        case children
        case body
        case transform
        case crossSection
        case mesh
        case material
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

        case .material (let body, let material):
            try container.encode(Kind.material, forKey: .kind)
            try container.encode(body, forKey: .body)
            try container.encode(material, forKey: .material)

        case .extrusion(let body, let type):
            try container.encode(Kind.extrusion, forKey: .kind)
            try container.encode(body, forKey: .crossSection)
            try container.encode(type, forKey: .type)

        case .raw(let manifold, _):
            try container.encode(Kind.raw, forKey: .kind)
            try container.encode(manifold.meshGL(), forKey: .mesh)
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
            let children = try container.decode([GeometryExpression3D].self, forKey: .children)
            self = .boolean(children, type: type)
        case .transform:
            let body = try container.decode(GeometryExpression3D.self, forKey: .body)
            let transform = try container.decode(AffineTransform3D.self, forKey: .transform)
            self = .transform(body, transform: transform)
        case .convexHull:
            let body = try container.decode(GeometryExpression3D.self, forKey: .body)
            self = .convexHull(body)
        case .material:
            let body = try container.decode(GeometryExpression3D.self, forKey: .body)
            let material = try container.decode(Material.self, forKey: .material)
            self = .material(body, material: material)
        case .extrusion:
            let body = try container.decode(GeometryExpression2D.self, forKey: .crossSection)
            let type = try container.decode(Extrusion.self, forKey: .type)
            self = .extrusion(body, type: type)
        case .raw:
            let meshGL = try container.decode(MeshGL.self, forKey: .mesh)
            self = .raw(try Manifold(meshGL), key: nil)
        }
    }
}
