import Foundation
import Manifold3D

extension GeometryNode3D: Codable {
    enum CodingKeys: String, CodingKey {
        case kind // Which geometry kind?
        case type // Subtype within kind
        case primitive
        case children
        case body
        case transform
        case crossSection
        case material
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

        case .materialized(let cacheKey):
            try container.encode(Kind.materialized, forKey: .kind)
            try container.encode(cacheKey, forKey: .cacheKey)

        case .applyMaterial (let body, let material):
            try container.encode(Kind.applyMaterial, forKey: .kind)
            try container.encode(body, forKey: .body)
            try container.encode(material, forKey: .material)

        case .lazyUnion(let children):
            try container.encode(Kind.lazyUnion, forKey: .kind)
            try container.encode(children, forKey: .children)
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
            let children = try container.decode([GeometryNode3D].self, forKey: .children)
            self.init(.boolean(children, type: type))
        case .transform:
            let body = try container.decode(GeometryNode3D.self, forKey: .body)
            let transform = try container.decode(AffineTransform3D.self, forKey: .transform)
            self.init(.transform(body, transform: transform))
        case .convexHull:
            let body = try container.decode(GeometryNode3D.self, forKey: .body)
            self.init(.convexHull(body))
        case .extrusion:
            let body = try container.decode(GeometryNode2D.self, forKey: .crossSection)
            let type = try container.decode(Extrusion.self, forKey: .type)
            self.init(.extrusion(body, type: type))
        case .materialized:
            let cacheKey = try container.decode(OpaqueKey.self, forKey: .cacheKey)
            self.init(.materialized(cacheKey: cacheKey))
        case .applyMaterial:
            let body = try container.decode(GeometryNode3D.self, forKey: .body)
            let material = try container.decode(Material.self, forKey: .material)
            self.init(.applyMaterial(body, material))
        case .lazyUnion:
            let children = try container.decode([GeometryNode3D].self, forKey: .children)
            self.init(.lazyUnion(children))
        }
    }
}

extension GeometryNode3D.PrimitiveShape {
    enum Kind: String, Codable, Hashable {
        case box
        case sphere
        case cylinder
        case convexHull
        case mesh
    }

    enum CodingKeys: String, CodingKey {
        case kind
        case size
        case radius
        case segmentCount
        case bottomRadius
        case topRadius
        case height
        case points
        case mesh
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        switch kind {
        case .box:
            let size = try container.decode(Vector3D.self, forKey: .size)
            self = .box(size: size)

        case .sphere:
            let radius = try container.decode(Double.self, forKey: .radius)
            let segmentCount = try container.decode(Int.self, forKey: .segmentCount)
            self = .sphere(radius: radius, segmentCount: segmentCount)

        case .cylinder:
            let bottomRadius = try container.decode(Double.self, forKey: .bottomRadius)
            let topRadius = try container.decode(Double.self, forKey: .topRadius)
            let height = try container.decode(Double.self, forKey: .height)
            let segmentCount = try container.decode(Int.self, forKey: .segmentCount)
            self = .cylinder(bottomRadius: bottomRadius, topRadius: topRadius, height: height, segmentCount: segmentCount)

        case .convexHull:
            let points = try container.decode([Vector3D].self, forKey: .points)
            self = .convexHull(points: points)

        case .mesh:
            let mesh = try container.decode(MeshData.self, forKey: .mesh)
            self = .mesh(mesh)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .box(let size):
            try container.encode(Kind.box, forKey: .kind)
            try container.encode(size, forKey: .size)

        case .sphere(let radius, let segmentCount):
            try container.encode(Kind.sphere, forKey: .kind)
            try container.encode(radius, forKey: .radius)
            try container.encode(segmentCount, forKey: .segmentCount)

        case .cylinder(let bottomRadius, let topRadius, let height, let segmentCount):
            try container.encode(Kind.cylinder, forKey: .kind)
            try container.encode(bottomRadius, forKey: .bottomRadius)
            try container.encode(topRadius, forKey: .topRadius)
            try container.encode(height, forKey: .height)
            try container.encode(segmentCount, forKey: .segmentCount)

        case .convexHull(let points):
            try container.encode(Kind.convexHull, forKey: .kind)
            try container.encode(points, forKey: .points)

        case .mesh(let mesh):
            try container.encode(Kind.mesh, forKey: .kind)
            try container.encode(mesh, forKey: .mesh)
        }
    }
}
