import Foundation

extension GeometryNode: Codable {
    enum Kind: String, Codable {
        case empty, boolean, transform, convexHull, refine, simplify, materialized
        case shape2D, offset, projection
        case shape3D, applyMaterial, extrusion, trim
    }

    enum CodingKeys: String, CodingKey {
        case kind, type, primitive, children, body, transform, edgeLength, tolerance
        case amount, joinStyle, miterLimit, segmentCount, cacheKey
        case material, crossSection, plane
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch contents {
        case .empty:
            try container.encode(Kind.empty, forKey: .kind)

        case .boolean(let children, let type):
            try container.encode(Kind.boolean, forKey: .kind)
            try container.encode(type, forKey: .type)
            try container.encode(children, forKey: .children)

        case .transform(let node, let transform):
            try container.encode(Kind.transform, forKey: .kind)
            try container.encode(node, forKey: .body)
            try container.encode(transform, forKey: .transform)

        case .convexHull(let node):
            try container.encode(Kind.convexHull, forKey: .kind)
            try container.encode(node, forKey: .body)

        case .refine(let node, let edgeLength):
            try container.encode(Kind.refine, forKey: .kind)
            try container.encode(node, forKey: .body)
            try container.encode(edgeLength, forKey: .edgeLength)

        case .simplify(let node, let tolerance):
            try container.encode(Kind.simplify, forKey: .kind)
            try container.encode(node, forKey: .body)
            try container.encode(tolerance, forKey: .tolerance)

        case .materialized(let cacheKey):
            try container.encode(Kind.materialized, forKey: .kind)
            try container.encode(cacheKey, forKey: .cacheKey)

        case .shape2D(let shape):
            try container.encode(Kind.shape2D, forKey: .kind)
            try container.encode(shape, forKey: .primitive)

        case .offset(let node, let amount, let joinStyle, let miterLimit, let segmentCount):
            try container.encode(Kind.offset, forKey: .kind)
            try container.encode(node, forKey: .body)
            try container.encode(amount, forKey: .amount)
            try container.encode(joinStyle, forKey: .joinStyle)
            try container.encode(miterLimit, forKey: .miterLimit)
            try container.encode(segmentCount, forKey: .segmentCount)

        case .projection(let node, let type):
            try container.encode(Kind.projection, forKey: .kind)
            try container.encode(node, forKey: .body)
            try container.encode(type, forKey: .type)

        case .shape3D(let shape):
            try container.encode(Kind.shape3D, forKey: .kind)
            try container.encode(shape, forKey: .primitive)

        case .applyMaterial(let node, let material):
            try container.encode(Kind.applyMaterial, forKey: .kind)
            try container.encode(node, forKey: .body)
            try container.encode(material, forKey: .material)

        case .extrusion(let node, let type):
            try container.encode(Kind.extrusion, forKey: .kind)
            try container.encode(node, forKey: .crossSection)
            try container.encode(type, forKey: .type)

        case .trim(let node, let plane):
            try container.encode(Kind.trim, forKey: .kind)
            try container.encode(node, forKey: .body)
            try container.encode(plane, forKey: .plane)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        switch kind {
        case .empty:
            self.init(.empty)
        case .boolean:
            let type = try container.decode(BooleanOperationType.self, forKey: .type)
            let children = try container.decode([D.Node].self, forKey: .children)
            self.init(.boolean(children, type: type))
        case .transform:
            let node = try container.decode(D.Node.self, forKey: .body)
            let transform = try container.decode(D.Transform.self, forKey: .transform)
            self.init(.transform(node, transform: transform))
        case .convexHull:
            let node = try container.decode(D.Node.self, forKey: .body)
            self.init(.convexHull(node))
        case .refine:
            let node = try container.decode(D.Node.self, forKey: .body)
            let edgeLength = try container.decode(Double.self, forKey: .edgeLength)
            self.init(.refine(node, edgeLength: edgeLength))
        case .simplify:
            let node = try container.decode(D.Node.self, forKey: .body)
            let tolerance = try container.decode(Double.self, forKey: .tolerance)
            self.init(.simplify(node, tolerance: tolerance))
        case .materialized:
            let cacheKey = try container.decode(OpaqueKey.self, forKey: .cacheKey)
            self.init(.materialized(cacheKey: cacheKey))
        case .shape2D:
            self.init(.shape2D(try container.decode(PrimitiveShape2D.self, forKey: .primitive)))
        case .offset:
            self.init(.offset(
                try container.decode(D2.Node.self, forKey: .body),
                amount: try container.decode(Double.self, forKey: .amount),
                joinStyle: try container.decode(LineJoinStyle.self, forKey: .joinStyle),
                miterLimit: try container.decode(Double.self, forKey: .miterLimit),
                segmentCount: try container.decode(Int.self, forKey: .segmentCount)
            ))
        case .projection:
            let node = try container.decode(D3.Node.self, forKey: .body)
            let type = try container.decode(Projection.self, forKey: .type)
            self.init(.projection(node, type: type))
        case .shape3D:
            self.init(.shape3D(try container.decode(PrimitiveShape3D.self, forKey: .primitive)))
        case .applyMaterial:
            let node = try container.decode(D3.Node.self, forKey: .body)
            let material = try container.decode(Material.self, forKey: .material)
            self.init(.applyMaterial(node, material))
        case .extrusion:
            let node = try container.decode(D2.Node.self, forKey: .crossSection)
            let type = try container.decode(Extrusion.self, forKey: .type)
            self.init(.extrusion(node, type: type))
        case .trim:
            let node = try container.decode(D3.Node.self, forKey: .body)
            let plane = try container.decode(Plane.self, forKey: .plane)
            self.init(.trim(node, plane))
        }
    }
}
