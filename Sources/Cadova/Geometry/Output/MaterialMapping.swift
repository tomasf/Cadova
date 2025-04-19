import Foundation
import Manifold3D

public struct Material: Hashable, Sendable, Codable {
    let name: String?
    let baseColor: Color
    let properties: Properties?

    init(name: String? = nil, baseColor: Color, properties: Properties? = nil) {
        self.name = name
        self.baseColor = baseColor
        self.properties = properties
    }

    enum Properties: Hashable, Sendable, Codable {
        case metallic (metallicness: Double, roughness: Double)
        case specular (color: Color, glossiness: Double)
    }

    static func plain(_ color: Color, alpha: Double? = nil) -> Material {
        return .init(baseColor: color.withAlphaComponent(alpha ?? color.alpha))
    }
}

struct MaterialMapping: ResultElement {
    let mapping: [D3.Primitive.OriginalID: Material]

    private init(mapping: [D3.Primitive.OriginalID: Material]) {
        self.mapping = mapping
    }

    init(originalID: D3.Primitive.OriginalID, material: Material) {
        self.init(mapping: [originalID: material])
    }

    static func combining(mappings: [MaterialMapping]) -> MaterialMapping {
        .init(mapping: mappings.reduce(into: [:]) { result, mapping in
            result.merge(mapping.mapping) { $1 }
        })
    }

    static func combine(elements: [MaterialMapping]) -> MaterialMapping? {
        .combining(mappings: elements)
    }
}

internal struct ApplyMaterial: ExpressionTransforming {
    typealias D = D3
    
    let body: any Geometry3D
    let material: Material

    func transform(expression: D3.Expression) -> D3.Expression {
        .material(expression, material: material)
    }
}
