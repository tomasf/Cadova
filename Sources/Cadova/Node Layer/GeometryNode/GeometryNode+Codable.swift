import Foundation

extension GeometryNode: Codable {
    enum Kind: String, Codable {
        case empty, boolean, transform, convexHull, refine, simplify, select, materialized
        case shape2D, offset, projection
        case shape3D, applyMaterial, extrusion, trim, smoothOut, decompose
    }

    enum CodingKeys: String, CodingKey {
        case kind, type, primitive, children, body, transform, edgeLength, tolerance, index
        case amount, joinStyle, miterLimit, segmentCount, cacheKey
        case material, crossSection, plane, minSharpAngle, minSmoothness
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

        case .select(let node, let index):
            try container.encode(Kind.select, forKey: .kind)
            try container.encode(node, forKey: .body)
            try container.encode(index, forKey: .index)

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

        case .smoothOut(let node, let minSharpAngle, let minSmoothness):
            try container.encode(Kind.smoothOut, forKey: .kind)
            try container.encode(node, forKey: .body)
            try container.encode(minSharpAngle, forKey: .minSharpAngle)
            try container.encode(minSmoothness, forKey: .minSmoothness)

        case .decompose(let node):
            try container.encode(Kind.decompose, forKey: .kind)
            try container.encode(node, forKey: .body)
        }
    }

    /// Decoding routes every case through the same normalizing factory that ordinary construction
    /// uses, rather than the raw memberwise initializer. Without that, a decoded tree could hold
    /// shapes the factories would never produce — nested unions, retained `.empty` children,
    /// unfolded transform chains — and would compare unequal to the same model built normally.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        switch kind {
        case .empty:
            self = .empty

        case .boolean:
            // No re-sort here. The encoded order already is the canonical one, because the
            // factory sorted the children by a digest that means the same thing in every process.
            let type = try container.decode(BooleanOperationType.self, forKey: .type)
            let children = try container.decode([D.Node].self, forKey: .children)
            self = .boolean(children, type: type)

        case .transform:
            self = .transform(
                try container.decode(D.Node.self, forKey: .body),
                transform: try container.decode(D.Transform.self, forKey: .transform)
            )

        case .convexHull:
            self = .convexHull(try container.decode(D.Node.self, forKey: .body))

        case .refine:
            self = .refine(
                try container.decode(D.Node.self, forKey: .body),
                maxEdgeLength: try container.decode(Double.self, forKey: .edgeLength)
            )

        case .simplify:
            self = .simplify(
                try container.decode(D.Node.self, forKey: .body),
                tolerance: try container.decode(Double.self, forKey: .tolerance)
            )

        case .select:
            self = .select(
                try container.decode(D.Node.self, forKey: .body),
                index: try container.decode(Int.self, forKey: .index)
            )

        case .decompose:
            self = .decompose(try container.decode(D.Node.self, forKey: .body))

        case .materialized:
            self = .materialized(cacheKey: try container.decode(AnyCacheKey.self, forKey: .cacheKey))

        case .shape2D:
            self = try Self.matchingDimensionality(GeometryNode<D2>.shape(
                try container.decode(GeometryNode<D2>.PrimitiveShape2D.self, forKey: .primitive)
            ), kind: kind)

        case .offset:
            self = try Self.matchingDimensionality(GeometryNode<D2>.offset(
                try container.decode(D2.Node.self, forKey: .body),
                amount: try container.decode(Double.self, forKey: .amount),
                joinStyle: try container.decode(LineJoinStyle.self, forKey: .joinStyle),
                miterLimit: try container.decode(Double.self, forKey: .miterLimit),
                segmentCount: try container.decode(Int.self, forKey: .segmentCount)
            ), kind: kind)

        case .projection:
            self = try Self.matchingDimensionality(GeometryNode<D2>.projection(
                try container.decode(D3.Node.self, forKey: .body),
                type: try container.decode(GeometryNode<D2>.Projection.self, forKey: .type)
            ), kind: kind)

        case .shape3D:
            self = try Self.matchingDimensionality(GeometryNode<D3>.shape(
                try container.decode(GeometryNode<D3>.PrimitiveShape3D.self, forKey: .primitive)
            ), kind: kind)

        case .applyMaterial:
            self = try Self.matchingDimensionality(GeometryNode<D3>.applyMaterial(
                try container.decode(D3.Node.self, forKey: .body),
                material: try container.decode(Material?.self, forKey: .material)
            ), kind: kind)

        case .extrusion:
            self = try Self.matchingDimensionality(GeometryNode<D3>.extrusion(
                try container.decode(D2.Node.self, forKey: .crossSection),
                type: try container.decode(GeometryNode<D3>.Extrusion.self, forKey: .type)
            ), kind: kind)

        case .trim:
            self = try Self.matchingDimensionality(GeometryNode<D3>.trim(
                try container.decode(D3.Node.self, forKey: .body),
                plane: try container.decode(Plane.self, forKey: .plane)
            ), kind: kind)

        case .smoothOut:
            self = try Self.matchingDimensionality(GeometryNode<D3>.smoothOut(
                try container.decode(D3.Node.self, forKey: .body),
                minSharpAngle: try container.decode(Double.self, forKey: .minSharpAngle),
                minSmoothness: try container.decode(Double.self, forKey: .minSmoothness)
            ), kind: kind)
        }
    }

    /// Several node kinds only exist in one dimensionality. Encountering one while decoding the
    /// other means the payload is corrupt, which is a decoding error rather than a crash.
    private static func matchingDimensionality<Other: Dimensionality>(
        _ node: GeometryNode<Other>, kind: Kind
    ) throws -> Self {
        guard let node = node as? Self else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: [],
                debugDescription: "Node of kind '\(kind.rawValue)' can't appear in \(D.self) geometry"
            ))
        }
        return node
    }
}
