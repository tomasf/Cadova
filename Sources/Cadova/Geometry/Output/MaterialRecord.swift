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
    var materials: Set<Material>

    init(materials: Set<Material>) {
        self.materials = materials
    }

    init() {
        self.init(materials: [])
    }

    init(combining records: [MaterialRecord]) {
        self.init(materials: records.reduce(into: Set<Material>()) { result, record in
            result.formUnion(record.materials)
        })
    }

    mutating func add(_ material: Material) {
        materials.insert(material)
    }

    func originalIDMapping(from context: EvaluationContext) async -> [Manifold.OriginalID: Material] {
        Dictionary(uniqueKeysWithValues: await materials.asyncCompactMap { material in
            let originalID = await context.taggedGeometry[material]
            return originalID.map { ($0, material) }
        })
    }
}

