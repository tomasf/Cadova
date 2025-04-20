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

struct MaterialRecord: ResultElement {
    var materials: Set<Material> = []

    init(materials: Set<Material>) {
        self.materials = materials
    }

    init() {}

    static func combining(mappings: [MaterialRecord]) -> MaterialRecord {
        .init(materials: mappings.reduce(into: Set<Material>()) { result, record in
            result.formUnion(record.materials)
        })
    }

    static func combine(elements: [MaterialRecord]) -> MaterialRecord? {
        .combining(mappings: elements)
    }

    mutating func add(_ material: Material) {
        materials.insert(material)
    }
}

