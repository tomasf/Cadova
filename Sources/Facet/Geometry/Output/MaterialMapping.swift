import Foundation
import Manifold3D

public struct Material: Sendable {
    let name: String?
    let baseColor: Color
    let properties: Properties?

    init(name: String? = nil, baseColor: Color, properties: Properties? = nil) {
        self.name = name
        self.baseColor = baseColor
        self.properties = properties
    }

    enum Properties {
        case metallic (metallicness: Double, roughness: Double)
        case specular (color: Color, glossiness: Double)
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

    static func combine(elements: [MaterialMapping], for operation: GeometryCombination) -> MaterialMapping? {
        .combining(mappings: elements)
    }
}

internal struct ApplyMaterial: Geometry3D {
    let body: any Geometry3D
    let material: Material

    func evaluated(in environment: EnvironmentValues) -> Output3D {
        let bodyOutput = body.evaluated(in: environment)
        let newMesh = bodyOutput.primitive.asOriginal()
        var elements = bodyOutput.elements
        guard let originalID = newMesh.originalID else {
            preconditionFailure("Original mesh returned nil originalID")
        }

        elements[MaterialMapping.self] = MaterialMapping(originalID: originalID, material: material)
        return Output3D(primitive: newMesh, elements: elements)
    }
}
